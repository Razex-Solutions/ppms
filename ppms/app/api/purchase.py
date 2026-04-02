from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.purchase import Purchase
from app.schemas.purchase import PurchaseCreate, PurchaseResponse
from app.services.purchases import create_purchase as create_purchase_service
from app.services.purchases import ensure_purchase_access, reverse_purchase as reverse_purchase_service

router = APIRouter(prefix="/purchases", tags=["Purchases"])


@router.post("/", response_model=PurchaseResponse)
def create_purchase(
    data: PurchaseCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    return create_purchase_service(db, data, current_user)


@router.get("/", response_model=list[PurchaseResponse])
def list_purchases(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    supplier_id: int | None = Query(None),
    fuel_type_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(Purchase)
    if station_id:
        q = q.join(Tank).filter(Tank.station_id == station_id)
    if supplier_id:
        q = q.filter(Purchase.supplier_id == supplier_id)
    if fuel_type_id:
        q = q.filter(Purchase.fuel_type_id == fuel_type_id)
    if from_date:
        q = q.filter(Purchase.created_at >= from_date)
    if to_date:
        q = q.filter(Purchase.created_at < to_date)
    return q.order_by(Purchase.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{purchase_id}", response_model=PurchaseResponse)
def get_purchase(
    purchase_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    purchase = db.query(Purchase).filter(Purchase.id == purchase_id).first()
    if not purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")

    ensure_purchase_access(purchase, current_user)

    return purchase


@router.post("/{purchase_id}/reverse", response_model=PurchaseResponse)
def reverse_purchase(
    purchase_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    purchase = db.query(Purchase).filter(Purchase.id == purchase_id).first()
    if not purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")

    return reverse_purchase_service(db, purchase, current_user)
