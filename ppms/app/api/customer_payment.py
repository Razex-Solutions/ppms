from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.customer_payment import CustomerPayment
from app.models.customer import Customer
from app.models.station import Station
from app.schemas.customer_payment import CustomerPaymentCreate, CustomerPaymentResponse

router = APIRouter(prefix="/customer-payments", tags=["Customer Payments"])


def _ensure_customer_payment_access(payment: CustomerPayment, current_user) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != payment.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this customer payment")


@router.post("/", response_model=CustomerPaymentResponse)
def create_customer_payment(
    data: CustomerPaymentCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
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
        notes=data.notes
    )

    db.add(payment)

    # reduce outstanding balance
    customer.outstanding_balance -= data.amount

    db.commit()
    db.refresh(payment)
    return payment


@router.get("/", response_model=list[CustomerPaymentResponse])
def list_customer_payments(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    customer_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(CustomerPayment)
    if station_id:
        q = q.filter(CustomerPayment.station_id == station_id)
    if customer_id:
        q = q.filter(CustomerPayment.customer_id == customer_id)
    if from_date:
        q = q.filter(CustomerPayment.created_at >= from_date)
    if to_date:
        q = q.filter(CustomerPayment.created_at < to_date)
    return q.order_by(CustomerPayment.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{payment_id}", response_model=CustomerPaymentResponse)
def get_customer_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(CustomerPayment).filter(CustomerPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Customer payment not found")

    _ensure_customer_payment_access(payment, current_user)
    return payment


@router.post("/{payment_id}/reverse", response_model=CustomerPaymentResponse)
def reverse_customer_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(CustomerPayment).filter(CustomerPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Customer payment not found")

    _ensure_customer_payment_access(payment, current_user)

    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Customer payment is already reversed")

    customer = db.query(Customer).filter(Customer.id == payment.customer_id).first()
    if customer is None:
        raise HTTPException(status_code=400, detail="Cannot reverse payment because the customer record is missing")

    customer.outstanding_balance += payment.amount
    payment.is_reversed = True
    payment.reversed_at = datetime.utcnow()
    payment.reversed_by = current_user.id

    db.commit()
    db.refresh(payment)
    return payment
