from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.purchase import Purchase
from app.models.station import Station
from app.models.tank import Tank
from app.schemas.purchase import PurchaseApprovalRequest, PurchaseCreate, PurchaseResponse, ReversalRequest
from app.services.purchases import approve_purchase as approve_purchase_service
from app.services.purchases import approve_purchase_reversal as approve_purchase_reversal_service
from app.services.purchases import create_purchase as create_purchase_service
from app.services.purchases import ensure_purchase_access, reverse_purchase as reverse_purchase_service
from app.services.purchases import reject_purchase as reject_purchase_service
from app.services.purchases import reject_purchase_reversal as reject_purchase_reversal_service
from app.services.purchases import request_purchase_reversal as request_purchase_reversal_service

router = APIRouter(prefix="/purchases", tags=["Purchases"])


@router.post("/", response_model=PurchaseResponse)
def create_purchase(
    data: PurchaseCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    require_permission(current_user, "purchases", "create", detail="You do not have permission to create purchases")
    return create_purchase_service(db, data, current_user)


@router.get("/", response_model=list[PurchaseResponse])
def list_purchases(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    supplier_id: int | None = Query(None),
    fuel_type_id: int | None = Query(None),
    status: str | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        pass
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
    else:
        station_id = current_user.station_id

    q = db.query(Purchase)
    if station_id:
        q = q.join(Tank).filter(Tank.station_id == station_id)
    if organization_id and station_id is None and (current_user.role.name == "Admin" or is_master_admin(current_user)):
        q = q.join(Tank).join(Station, Station.id == Tank.station_id).filter(Station.organization_id == organization_id)
    elif organization_id and station_id is None and is_head_office_user(current_user):
        q = q.join(Tank).join(Station, Station.id == Tank.station_id).filter(Station.organization_id == organization_id)
    if supplier_id:
        q = q.filter(Purchase.supplier_id == supplier_id)
    if fuel_type_id:
        q = q.filter(Purchase.fuel_type_id == fuel_type_id)
    if status:
        q = q.filter(Purchase.status == status)
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


@router.post("/{purchase_id}/approve", response_model=PurchaseResponse)
def approve_purchase(
    purchase_id: int,
    data: PurchaseApprovalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    purchase = db.query(Purchase).filter(Purchase.id == purchase_id).first()
    if not purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")

    require_permission(current_user, "purchases", "approve", detail="You do not have permission to approve purchases")
    return approve_purchase_service(db, purchase, current_user, data.reason if data else None)


@router.post("/{purchase_id}/reject", response_model=PurchaseResponse)
def reject_purchase(
    purchase_id: int,
    data: PurchaseApprovalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    purchase = db.query(Purchase).filter(Purchase.id == purchase_id).first()
    if not purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")

    require_permission(current_user, "purchases", "reject", detail="You do not have permission to reject purchases")
    return reject_purchase_service(db, purchase, current_user, data.reason if data else None)


@router.post("/{purchase_id}/reverse", response_model=PurchaseResponse)
def reverse_purchase(
    purchase_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    purchase = db.query(Purchase).filter(Purchase.id == purchase_id).first()
    if not purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")

    require_permission(current_user, "purchases", "reverse", detail="You do not have permission to reverse purchases")
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return reverse_purchase_service(db, purchase, current_user)
    return request_purchase_reversal_service(db, purchase, current_user, data.reason if data else None)


@router.post("/{purchase_id}/approve-reversal", response_model=PurchaseResponse)
def approve_purchase_reversal(
    purchase_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    purchase = db.query(Purchase).filter(Purchase.id == purchase_id).first()
    if not purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")

    require_permission(current_user, "purchases", "approve_reverse", detail="You do not have permission to approve purchase reversals")
    return approve_purchase_reversal_service(db, purchase, current_user, data.reason if data else None)


@router.post("/{purchase_id}/reject-reversal", response_model=PurchaseResponse)
def reject_purchase_reversal(
    purchase_id: int,
    data: ReversalRequest | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    purchase = db.query(Purchase).filter(Purchase.id == purchase_id).first()
    if not purchase:
        raise HTTPException(status_code=404, detail="Purchase not found")

    require_permission(current_user, "purchases", "reject_reverse", detail="You do not have permission to reject purchase reversals")
    return reject_purchase_reversal_service(db, purchase, current_user, data.reason if data else None)
