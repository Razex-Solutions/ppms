from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user
from app.core.time import utc_now
from app.models.customer import Customer
from app.models.customer_payment import CustomerPayment
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.supplier_payment import SupplierPayment
from app.models.user import User
from app.schemas.customer_payment import CustomerPaymentCreate
from app.schemas.supplier_payment import SupplierPaymentCreate
from app.services.audit import log_audit_event


def ensure_customer_payment_access(payment: CustomerPayment, current_user: User) -> None:
    if current_user.role.name == "Admin":
        return
    if is_head_office_user(current_user):
        station = payment.customer.station if hasattr(payment, "customer") and payment.customer else None
        if station is None:
            raise HTTPException(status_code=403, detail="Not authorized for this customer payment")
        if station.organization_id == get_user_organization_id(current_user):
            return
        raise HTTPException(status_code=403, detail="Not authorized for this customer payment")
    if current_user.station_id != payment.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this customer payment")


def ensure_supplier_payment_access(payment: SupplierPayment, current_user: User) -> None:
    if current_user.role.name == "Admin":
        return
    if is_head_office_user(current_user):
        station = payment.station
        if station and station.organization_id == get_user_organization_id(current_user):
            return
        raise HTTPException(status_code=403, detail="Not authorized for this supplier payment")
    if current_user.station_id != payment.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this supplier payment")


def create_customer_payment(db: Session, data: CustomerPaymentCreate, current_user: User) -> CustomerPayment:
    if current_user.role.name != "Admin" and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Payment amount must be greater than 0")

    customer = db.query(Customer).filter(Customer.id == data.customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if customer.station_id != data.station_id:
        raise HTTPException(status_code=400, detail="Customer does not belong to the selected station")
    if customer.outstanding_balance <= 0:
        raise HTTPException(status_code=400, detail="Customer has no outstanding balance")
    if data.amount > customer.outstanding_balance:
        raise HTTPException(status_code=400, detail="Payment exceeds outstanding balance")

    payment = CustomerPayment(
        customer_id=data.customer_id,
        station_id=data.station_id,
        amount=data.amount,
        payment_method=data.payment_method,
        reference_no=data.reference_no,
        notes=data.notes,
    )
    db.add(payment)
    customer.outstanding_balance -= data.amount
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="customer_payments",
        action="customer_payments.create",
        entity_type="customer_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"customer_id": payment.customer_id, "amount": payment.amount},
    )
    db.commit()
    db.refresh(payment)
    return payment


def reverse_customer_payment(db: Session, payment: CustomerPayment, current_user: User) -> CustomerPayment:
    ensure_customer_payment_access(payment, current_user)
    if payment.reversal_request_status != "approved" and current_user.role.name != "Admin":
        raise HTTPException(status_code=400, detail="Customer payment reversal must be approved first")
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Customer payment is already reversed")
    customer = db.query(Customer).filter(Customer.id == payment.customer_id).first()
    if customer is None:
        raise HTTPException(status_code=400, detail="Cannot reverse payment because the customer record is missing")
    customer.outstanding_balance += payment.amount
    payment.is_reversed = True
    payment.reversed_at = utc_now()
    payment.reversed_by = current_user.id
    log_audit_event(
        db,
        current_user=current_user,
        module="customer_payments",
        action="customer_payments.reverse",
        entity_type="customer_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"customer_id": payment.customer_id, "amount": payment.amount},
    )
    db.commit()
    db.refresh(payment)
    return payment


def request_customer_payment_reversal(db: Session, payment: CustomerPayment, current_user: User, reason: str | None = None) -> CustomerPayment:
    ensure_customer_payment_access(payment, current_user)
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Customer payment is already reversed")
    if payment.reversal_request_status == "pending":
        raise HTTPException(status_code=400, detail="Customer payment reversal is already pending approval")
    payment.reversal_request_status = "pending"
    payment.reversal_requested_at = utc_now()
    payment.reversal_requested_by = current_user.id
    payment.reversal_request_reason = reason
    payment.reversal_reviewed_at = None
    payment.reversal_reviewed_by = None
    payment.reversal_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="customer_payments",
        action="customer_payments.request_reversal",
        entity_type="customer_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"reason": reason},
    )
    db.commit()
    db.refresh(payment)
    return payment


def approve_customer_payment_reversal(db: Session, payment: CustomerPayment, current_user: User, reason: str | None = None) -> CustomerPayment:
    ensure_customer_payment_access(payment, current_user)
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Customer payment is already reversed")
    if payment.reversal_request_status not in {"pending", "approved"}:
        raise HTTPException(status_code=400, detail="Customer payment reversal has not been requested")
    payment.reversal_request_status = "approved"
    payment.reversal_reviewed_at = utc_now()
    payment.reversal_reviewed_by = current_user.id
    payment.reversal_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="customer_payments",
        action="customer_payments.approve_reversal",
        entity_type="customer_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"reason": reason},
    )
    db.flush()
    return reverse_customer_payment(db, payment, current_user)


def reject_customer_payment_reversal(db: Session, payment: CustomerPayment, current_user: User, reason: str | None = None) -> CustomerPayment:
    ensure_customer_payment_access(payment, current_user)
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Customer payment is already reversed")
    if payment.reversal_request_status != "pending":
        raise HTTPException(status_code=400, detail="Customer payment reversal is not pending approval")
    payment.reversal_request_status = "rejected"
    payment.reversal_reviewed_at = utc_now()
    payment.reversal_reviewed_by = current_user.id
    payment.reversal_rejection_reason = reason
    log_audit_event(
        db,
        current_user=current_user,
        module="customer_payments",
        action="customer_payments.reject_reversal",
        entity_type="customer_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"reason": reason},
    )
    db.commit()
    db.refresh(payment)
    return payment


def create_supplier_payment(db: Session, data: SupplierPaymentCreate, current_user: User) -> SupplierPayment:
    if current_user.role.name != "Admin" and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Payment amount must be greater than 0")

    supplier = db.query(Supplier).filter(Supplier.id == data.supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if supplier.payable_balance <= 0:
        raise HTTPException(status_code=400, detail="Supplier has no payable balance")
    if data.amount > supplier.payable_balance:
        raise HTTPException(status_code=400, detail="Payment exceeds payable balance")

    payment = SupplierPayment(
        supplier_id=data.supplier_id,
        station_id=data.station_id,
        amount=data.amount,
        payment_method=data.payment_method,
        reference_no=data.reference_no,
        notes=data.notes,
    )
    db.add(payment)
    supplier.payable_balance -= data.amount
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="supplier_payments",
        action="supplier_payments.create",
        entity_type="supplier_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"supplier_id": payment.supplier_id, "amount": payment.amount},
    )
    db.commit()
    db.refresh(payment)
    return payment


def reverse_supplier_payment(db: Session, payment: SupplierPayment, current_user: User) -> SupplierPayment:
    ensure_supplier_payment_access(payment, current_user)
    if payment.reversal_request_status != "approved" and current_user.role.name != "Admin":
        raise HTTPException(status_code=400, detail="Supplier payment reversal must be approved first")
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Supplier payment is already reversed")
    supplier = db.query(Supplier).filter(Supplier.id == payment.supplier_id).first()
    if supplier is None:
        raise HTTPException(status_code=400, detail="Cannot reverse payment because the supplier record is missing")
    supplier.payable_balance += payment.amount
    payment.is_reversed = True
    payment.reversed_at = utc_now()
    payment.reversed_by = current_user.id
    log_audit_event(
        db,
        current_user=current_user,
        module="supplier_payments",
        action="supplier_payments.reverse",
        entity_type="supplier_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"supplier_id": payment.supplier_id, "amount": payment.amount},
    )
    db.commit()
    db.refresh(payment)
    return payment


def request_supplier_payment_reversal(db: Session, payment: SupplierPayment, current_user: User, reason: str | None = None) -> SupplierPayment:
    ensure_supplier_payment_access(payment, current_user)
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Supplier payment is already reversed")
    if payment.reversal_request_status == "pending":
        raise HTTPException(status_code=400, detail="Supplier payment reversal is already pending approval")
    payment.reversal_request_status = "pending"
    payment.reversal_requested_at = utc_now()
    payment.reversal_requested_by = current_user.id
    payment.reversal_request_reason = reason
    payment.reversal_reviewed_at = None
    payment.reversal_reviewed_by = None
    payment.reversal_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="supplier_payments",
        action="supplier_payments.request_reversal",
        entity_type="supplier_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"reason": reason},
    )
    db.commit()
    db.refresh(payment)
    return payment


def approve_supplier_payment_reversal(db: Session, payment: SupplierPayment, current_user: User, reason: str | None = None) -> SupplierPayment:
    ensure_supplier_payment_access(payment, current_user)
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Supplier payment is already reversed")
    if payment.reversal_request_status not in {"pending", "approved"}:
        raise HTTPException(status_code=400, detail="Supplier payment reversal has not been requested")
    payment.reversal_request_status = "approved"
    payment.reversal_reviewed_at = utc_now()
    payment.reversal_reviewed_by = current_user.id
    payment.reversal_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="supplier_payments",
        action="supplier_payments.approve_reversal",
        entity_type="supplier_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"reason": reason},
    )
    db.flush()
    return reverse_supplier_payment(db, payment, current_user)


def reject_supplier_payment_reversal(db: Session, payment: SupplierPayment, current_user: User, reason: str | None = None) -> SupplierPayment:
    ensure_supplier_payment_access(payment, current_user)
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Supplier payment is already reversed")
    if payment.reversal_request_status != "pending":
        raise HTTPException(status_code=400, detail="Supplier payment reversal is not pending approval")
    payment.reversal_request_status = "rejected"
    payment.reversal_reviewed_at = utc_now()
    payment.reversal_reviewed_by = current_user.id
    payment.reversal_rejection_reason = reason
    log_audit_event(
        db,
        current_user=current_user,
        module="supplier_payments",
        action="supplier_payments.reject_reversal",
        entity_type="supplier_payment",
        entity_id=payment.id,
        station_id=payment.station_id,
        details={"reason": reason},
    )
    db.commit()
    db.refresh(payment)
    return payment
