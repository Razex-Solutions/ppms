from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.time import utc_now
from app.models.customer import Customer
from app.models.customer_credit_issue import CustomerCreditIssue
from app.models.fuel_price_history import FuelPriceHistory
from app.models.nozzle import Nozzle
from app.models.role import Role
from app.models.shift import Shift
from app.models.station import Station
from app.models.user import User
from app.schemas.customer import CreditOverrideRequest, CustomerCreate, CustomerUpdate, ManagerCreditAdjustmentRequest, ManagerCreditIssueRequest
from app.services.audit import log_audit_event
from app.services.notifications import notify_users


def _ensure_customer_scope(customer: Customer, current_user: User) -> None:
    if is_master_admin(current_user):
        return
    if is_head_office_user(current_user):
        if customer.station and customer.station.organization_id == get_user_organization_id(current_user):
            return
        raise HTTPException(status_code=403, detail="Not authorized for this customer")
    if current_user.station_id != customer.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this customer")


def create_customer(db: Session, data: CustomerCreate, current_user: User) -> Customer:
    if not is_master_admin(current_user) and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    existing = db.query(Customer).filter(Customer.code == data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Customer code already exists")
    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    customer = Customer(
        name=data.name,
        code=data.code,
        customer_type=data.customer_type,
        phone=data.phone,
        address=data.address,
        credit_limit=data.credit_limit,
        outstanding_balance=0,
        credit_override_amount=0,
        credit_override_requested_amount=0,
        station_id=data.station_id,
    )
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer


def update_customer(customer: Customer, data: CustomerUpdate, db: Session) -> Customer:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(customer, field, value)
    db.commit()
    db.refresh(customer)
    return customer


def request_credit_override(customer: Customer, data: CreditOverrideRequest, db: Session, current_user: User) -> Customer:
    _ensure_customer_scope(customer, current_user)
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Override amount must be greater than 0")
    customer.credit_override_status = "pending"
    customer.credit_override_requested_amount = data.amount
    customer.credit_override_requested_at = utc_now()
    customer.credit_override_requested_by = current_user.id
    customer.credit_override_reason = data.reason
    customer.credit_override_reviewed_at = None
    customer.credit_override_reviewed_by = None
    customer.credit_override_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="customers",
        action="customers.request_credit_override",
        entity_type="customer",
        entity_id=customer.id,
        station_id=customer.station_id,
        details={"amount": data.amount, "reason": data.reason},
    )
    db.commit()
    db.refresh(customer)
    return customer


def approve_credit_override(customer: Customer, data: CreditOverrideRequest, db: Session, current_user: User) -> Customer:
    _ensure_customer_scope(customer, current_user)
    if customer.credit_override_status != "pending":
        raise HTTPException(status_code=400, detail="Customer credit override is not pending approval")
    customer.credit_override_status = "approved"
    customer.credit_override_amount = customer.credit_override_requested_amount
    customer.credit_override_reviewed_at = utc_now()
    customer.credit_override_reviewed_by = current_user.id
    customer.credit_override_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="customers",
        action="customers.approve_credit_override",
        entity_type="customer",
        entity_id=customer.id,
        station_id=customer.station_id,
        details={"amount": customer.credit_override_amount, "reason": data.reason},
    )
    db.commit()
    db.refresh(customer)
    return customer


def reject_credit_override(customer: Customer, data: CreditOverrideRequest, db: Session, current_user: User) -> Customer:
    _ensure_customer_scope(customer, current_user)
    if customer.credit_override_status != "pending":
        raise HTTPException(status_code=400, detail="Customer credit override is not pending approval")
    customer.credit_override_status = "rejected"
    customer.credit_override_amount = 0
    customer.credit_override_reviewed_at = utc_now()
    customer.credit_override_reviewed_by = current_user.id
    customer.credit_override_rejection_reason = data.reason
    log_audit_event(
        db,
        current_user=current_user,
        module="customers",
        action="customers.reject_credit_override",
        entity_type="customer",
        entity_id=customer.id,
        station_id=customer.station_id,
        details={"amount": customer.credit_override_requested_amount, "reason": data.reason},
    )
    db.commit()
    db.refresh(customer)
    return customer


def manager_adjust_credit_limit(
    customer: Customer,
    data: ManagerCreditAdjustmentRequest,
    db: Session,
    current_user: User,
) -> Customer:
    _ensure_customer_scope(customer, current_user)
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Adjustment amount must be greater than 0")

    before_limit = customer.credit_limit or 0.0
    customer.credit_limit = round(before_limit + data.amount, 2)
    customer.credit_override_status = "notified"
    customer.credit_override_amount = round(data.amount, 2)
    customer.credit_override_requested_amount = round(data.amount, 2)
    customer.credit_override_requested_at = utc_now()
    customer.credit_override_requested_by = current_user.id
    customer.credit_override_reason = data.reason
    customer.credit_override_reviewed_at = None
    customer.credit_override_reviewed_by = None
    customer.credit_override_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="customers",
        action="customers.manager_adjust_credit_limit",
        entity_type="customer",
        entity_id=customer.id,
        station_id=customer.station_id,
        details={
            "before_credit_limit": before_limit,
            "increase_amount": data.amount,
            "after_credit_limit": customer.credit_limit,
            "reason": data.reason,
        },
    )

    recipients = (
        db.query(User)
        .join(Role, User.role_id == Role.id)
        .filter(
            User.is_active.is_(True),
            (
                ((Role.name == "StationAdmin") & (User.station_id == customer.station_id)) |
                ((Role.name == "HeadOffice") & (User.organization_id == customer.station.organization_id)) |
                (Role.name == "MasterAdmin")
            ),
        )
        .all()
    )
    notify_users(
        db,
        recipients=recipients,
        actor_user=current_user,
        station_id=customer.station_id,
        organization_id=customer.station.organization_id if customer.station else None,
        event_type="customer.credit_limit_increased",
        title="Customer credit increased",
        message=(
            f"{current_user.full_name} increased credit for {customer.name} by {data.amount:.2f}. "
            f"New limit: {customer.credit_limit:.2f}."
        ),
        entity_type="customer",
        entity_id=customer.id,
    )
    db.commit()
    db.refresh(customer)
    return customer


def manager_record_credit_issue(
    customer: Customer,
    data: ManagerCreditIssueRequest,
    db: Session,
    current_user: User,
) -> CustomerCreditIssue:
    _ensure_customer_scope(customer, current_user)
    if data.quantity <= 0:
        raise HTTPException(status_code=400, detail="Credit quantity must be greater than 0")

    shift_id = None
    if data.shift_id is not None:
        shift = db.query(Shift).filter(Shift.id == data.shift_id).first()
        if shift is None:
            raise HTTPException(status_code=404, detail="Shift not found")
        if shift.station_id != customer.station_id:
            raise HTTPException(status_code=400, detail="Shift does not belong to this customer station")
        shift_id = shift.id

    nozzle = db.query(Nozzle).filter(Nozzle.id == data.nozzle_id).first()
    if nozzle is None:
        raise HTTPException(status_code=404, detail="Nozzle not found")
    if nozzle.dispenser is None or nozzle.dispenser.station_id != customer.station_id:
        raise HTTPException(status_code=400, detail="Nozzle does not belong to this customer station")

    latest_price = (
        db.query(FuelPriceHistory)
        .filter(
            FuelPriceHistory.station_id == customer.station_id,
            FuelPriceHistory.fuel_type_id == nozzle.fuel_type_id,
        )
        .order_by(FuelPriceHistory.effective_at.desc(), FuelPriceHistory.id.desc())
        .first()
    )
    if latest_price is None:
        raise HTTPException(status_code=400, detail="No active fuel price is configured for this nozzle fuel type")

    total_amount = round(float(data.quantity) * float(latest_price.price), 2)

    credit_issue = CustomerCreditIssue(
        customer_id=customer.id,
        station_id=customer.station_id,
        shift_id=shift_id,
        nozzle_id=nozzle.id,
        tank_id=nozzle.tank_id,
        fuel_type_id=nozzle.fuel_type_id,
        quantity=round(float(data.quantity), 2),
        rate_per_liter=round(float(latest_price.price), 2),
        amount=total_amount,
        notes=data.notes,
        created_by_user_id=current_user.id,
    )
    db.add(credit_issue)
    db.flush()

    before_balance = customer.outstanding_balance or 0.0
    customer.outstanding_balance = round(before_balance + total_amount, 2)

    log_audit_event(
        db,
        current_user=current_user,
        module="customers",
        action="customers.manager_record_credit_issue",
        entity_type="customer_credit_issue",
        entity_id=credit_issue.id,
        station_id=customer.station_id,
        details={
            "customer_id": customer.id,
            "nozzle_id": nozzle.id,
            "tank_id": nozzle.tank_id,
            "fuel_type_id": nozzle.fuel_type_id,
            "before_outstanding_balance": before_balance,
            "quantity": credit_issue.quantity,
            "rate_per_liter": credit_issue.rate_per_liter,
            "credit_issued": credit_issue.amount,
            "after_outstanding_balance": customer.outstanding_balance,
            "notes": data.notes,
        },
    )

    if customer.outstanding_balance > (customer.credit_limit or 0.0):
        recipients = (
            db.query(User)
            .join(Role, User.role_id == Role.id)
            .filter(
                User.is_active.is_(True),
                (
                    ((Role.name == "StationAdmin") & (User.station_id == customer.station_id)) |
                    ((Role.name == "HeadOffice") & (User.organization_id == customer.station.organization_id)) |
                    (Role.name == "MasterAdmin")
                ),
            )
            .all()
        )
        notify_users(
            db,
            recipients=recipients,
            actor_user=current_user,
            station_id=customer.station_id,
            organization_id=customer.station.organization_id if customer.station else None,
            event_type="customer.credit_limit_exceeded",
            title="Customer credit exposure exceeded",
            message=(
                f"{customer.name} is now above the credit limit after manager credit entry. "
                f"Outstanding: {customer.outstanding_balance:.2f}, limit: {(customer.credit_limit or 0.0):.2f}."
            ),
            entity_type="customer",
            entity_id=customer.id,
        )

    db.commit()
    db.refresh(credit_issue)
    return credit_issue
