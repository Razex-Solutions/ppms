from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.customer_payment import CustomerPayment
from app.schemas.customer_payment import CustomerPaymentCreate, CustomerPaymentResponse, ReversalRequest
from app.services.payments import approve_customer_payment_reversal as approve_customer_payment_reversal_service
from app.services.payments import create_customer_payment as create_customer_payment_service
from app.services.payments import ensure_customer_payment_access, reverse_customer_payment as reverse_customer_payment_service
from app.services.payments import reject_customer_payment_reversal as reject_customer_payment_reversal_service
from app.services.payments import request_customer_payment_reversal as request_customer_payment_reversal_service

router = APIRouter(prefix="/customer-payments", tags=["Customer Payments"])


@router.post("/", response_model=CustomerPaymentResponse)
def create_customer_payment(
    data: CustomerPaymentCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    require_permission(current_user, "customer_payments", "create", detail="You do not have permission to create customer payments")
    return create_customer_payment_service(db, data, current_user)


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

    ensure_customer_payment_access(payment, current_user)
    return payment


@router.post("/{payment_id}/reverse", response_model=CustomerPaymentResponse)
def reverse_customer_payment(
    payment_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(CustomerPayment).filter(CustomerPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Customer payment not found")

    require_permission(current_user, "customer_payments", "reverse", detail="You do not have permission to reverse customer payments")
    if current_user.role.name == "Admin":
        return reverse_customer_payment_service(db, payment, current_user)
    return request_customer_payment_reversal_service(db, payment, current_user, data.reason if data else None)


@router.post("/{payment_id}/approve-reversal", response_model=CustomerPaymentResponse)
def approve_customer_payment_reversal(
    payment_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(CustomerPayment).filter(CustomerPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Customer payment not found")

    require_permission(current_user, "customer_payments", "approve_reverse", detail="You do not have permission to approve customer payment reversals")
    return approve_customer_payment_reversal_service(db, payment, current_user, data.reason if data else None)


@router.post("/{payment_id}/reject-reversal", response_model=CustomerPaymentResponse)
def reject_customer_payment_reversal(
    payment_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(CustomerPayment).filter(CustomerPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Customer payment not found")

    require_permission(current_user, "customer_payments", "reject_reverse", detail="You do not have permission to reject customer payment reversals")
    return reject_customer_payment_reversal_service(db, payment, current_user, data.reason if data else None)
