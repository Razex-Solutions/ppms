from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models.customer import Customer
from app.models.customer_payment import CustomerPayment
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.supplier_payment import SupplierPayment
from app.models.user import User
from app.schemas.customer_payment import CustomerPaymentCreate
from app.schemas.supplier_payment import SupplierPaymentCreate


def ensure_customer_payment_access(payment: CustomerPayment, current_user: User) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != payment.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this customer payment")


def ensure_supplier_payment_access(payment: SupplierPayment, current_user: User) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != payment.station_id:
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
    db.commit()
    db.refresh(payment)
    return payment


def reverse_customer_payment(db: Session, payment: CustomerPayment, current_user: User) -> CustomerPayment:
    ensure_customer_payment_access(payment, current_user)
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Customer payment is already reversed")
    customer = db.query(Customer).filter(Customer.id == payment.customer_id).first()
    if customer is None:
        raise HTTPException(status_code=400, detail="Cannot reverse payment because the customer record is missing")
    customer.outstanding_balance += payment.amount
    payment.is_reversed = True
    payment.reversed_at = utc_now()
    payment.reversed_by = current_user.id
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
    db.commit()
    db.refresh(payment)
    return payment


def reverse_supplier_payment(db: Session, payment: SupplierPayment, current_user: User) -> SupplierPayment:
    ensure_supplier_payment_access(payment, current_user)
    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Supplier payment is already reversed")
    supplier = db.query(Supplier).filter(Supplier.id == payment.supplier_id).first()
    if supplier is None:
        raise HTTPException(status_code=400, detail="Cannot reverse payment because the supplier record is missing")
    supplier.payable_balance += payment.amount
    payment.is_reversed = True
    payment.reversed_at = utc_now()
    payment.reversed_by = current_user.id
    db.commit()
    db.refresh(payment)
    return payment
