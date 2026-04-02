from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.supplier_payment import SupplierPayment
from app.models.supplier import Supplier
from app.models.station import Station
from app.schemas.supplier_payment import SupplierPaymentCreate, SupplierPaymentResponse

router = APIRouter(prefix="/supplier-payments", tags=["Supplier Payments"])


def _ensure_supplier_payment_access(payment: SupplierPayment, current_user) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != payment.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this supplier payment")


@router.post("/", response_model=SupplierPaymentResponse)
def create_supplier_payment(
    data: SupplierPaymentCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
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
        notes=data.notes
    )

    db.add(payment)

    supplier.payable_balance -= data.amount

    db.commit()
    db.refresh(payment)
    return payment


@router.get("/", response_model=list[SupplierPaymentResponse])
def list_supplier_payments(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    supplier_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(SupplierPayment)
    if station_id:
        q = q.filter(SupplierPayment.station_id == station_id)
    if supplier_id:
        q = q.filter(SupplierPayment.supplier_id == supplier_id)
    if from_date:
        q = q.filter(SupplierPayment.created_at >= from_date)
    if to_date:
        q = q.filter(SupplierPayment.created_at < to_date)
    return q.order_by(SupplierPayment.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{payment_id}", response_model=SupplierPaymentResponse)
def get_supplier_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(SupplierPayment).filter(SupplierPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Supplier payment not found")

    _ensure_supplier_payment_access(payment, current_user)
    return payment


@router.post("/{payment_id}/reverse", response_model=SupplierPaymentResponse)
def reverse_supplier_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(SupplierPayment).filter(SupplierPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Supplier payment not found")

    _ensure_supplier_payment_access(payment, current_user)

    if payment.is_reversed:
        raise HTTPException(status_code=400, detail="Supplier payment is already reversed")

    supplier = db.query(Supplier).filter(Supplier.id == payment.supplier_id).first()
    if supplier is None:
        raise HTTPException(status_code=400, detail="Cannot reverse payment because the supplier record is missing")

    supplier.payable_balance += payment.amount
    payment.is_reversed = True
    payment.reversed_at = datetime.utcnow()
    payment.reversed_by = current_user.id

    db.commit()
    db.refresh(payment)
    return payment
