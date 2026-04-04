from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.time import utc_now
from app.models.customer import Customer
from app.models.station import Station
from app.models.user import User
from app.schemas.customer import CreditOverrideRequest, CustomerCreate, CustomerUpdate
from app.services.audit import log_audit_event


def _ensure_customer_scope(customer: Customer, current_user: User) -> None:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return
    if is_head_office_user(current_user):
        if customer.station and customer.station.organization_id == get_user_organization_id(current_user):
            return
        raise HTTPException(status_code=403, detail="Not authorized for this customer")
    if current_user.station_id != customer.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this customer")


def create_customer(db: Session, data: CustomerCreate, current_user: User) -> Customer:
    if current_user.role.name != "Admin" and not is_master_admin(current_user) and current_user.station_id != data.station_id:
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
