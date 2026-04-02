from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.supplier_payment import SupplierPayment
from app.schemas.supplier_payment import ReversalRequest, SupplierPaymentCreate, SupplierPaymentResponse
from app.services.payments import approve_supplier_payment_reversal as approve_supplier_payment_reversal_service
from app.services.payments import create_supplier_payment as create_supplier_payment_service
from app.services.payments import ensure_supplier_payment_access, reverse_supplier_payment as reverse_supplier_payment_service
from app.services.payments import reject_supplier_payment_reversal as reject_supplier_payment_reversal_service
from app.services.payments import request_supplier_payment_reversal as request_supplier_payment_reversal_service

router = APIRouter(prefix="/supplier-payments", tags=["Supplier Payments"])


@router.post("/", response_model=SupplierPaymentResponse)
def create_supplier_payment(
    data: SupplierPaymentCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    require_permission(current_user, "supplier_payments", "create", detail="You do not have permission to create supplier payments")
    return create_supplier_payment_service(db, data, current_user)


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

    ensure_supplier_payment_access(payment, current_user)
    return payment


@router.post("/{payment_id}/reverse", response_model=SupplierPaymentResponse)
def reverse_supplier_payment(
    payment_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(SupplierPayment).filter(SupplierPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Supplier payment not found")

    require_permission(current_user, "supplier_payments", "reverse", detail="You do not have permission to reverse supplier payments")
    if current_user.role.name == "Admin":
        return reverse_supplier_payment_service(db, payment, current_user)
    return request_supplier_payment_reversal_service(db, payment, current_user, data.reason if data else None)


@router.post("/{payment_id}/approve-reversal", response_model=SupplierPaymentResponse)
def approve_supplier_payment_reversal(
    payment_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(SupplierPayment).filter(SupplierPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Supplier payment not found")

    require_permission(current_user, "supplier_payments", "approve_reverse", detail="You do not have permission to approve supplier payment reversals")
    return approve_supplier_payment_reversal_service(db, payment, current_user, data.reason if data else None)


@router.post("/{payment_id}/reject-reversal", response_model=SupplierPaymentResponse)
def reject_supplier_payment_reversal(
    payment_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    payment = db.query(SupplierPayment).filter(SupplierPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Supplier payment not found")

    require_permission(current_user, "supplier_payments", "reject_reverse", detail="You do not have permission to reject supplier payment reversals")
    return reject_supplier_payment_reversal_service(db, payment, current_user, data.reason if data else None)
