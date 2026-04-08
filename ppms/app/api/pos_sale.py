from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.pos_sale import POSSale
from app.models.pos_sale_item import POSSaleItem
from app.models.user import User
from app.schemas.pos_sale import POSSaleCreate, POSSaleResponse
from app.services.pos import create_pos_sale as create_pos_sale_service
from app.services.pos import ensure_pos_sale_access, reverse_pos_sale as reverse_pos_sale_service

router = APIRouter(prefix="/pos-sales", tags=["POS Sales"])


def _attach_items(db: Session, sale: POSSale) -> POSSale:
    sale.items = db.query(POSSaleItem).filter(POSSaleItem.sale_id == sale.id).all()
    return sale


@router.post("/", response_model=POSSaleResponse)
def create_pos_sale(
    data: POSSaleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_permission(current_user, "pos_sales", "create", detail="You do not have permission to create POS sales")
    return create_pos_sale_service(db, data, current_user)


@router.get("/", response_model=list[POSSaleResponse])
def list_pos_sales(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    module: str | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not is_master_admin(current_user):
        station_id = current_user.station_id

    q = db.query(POSSale)
    if station_id:
        q = q.filter(POSSale.station_id == station_id)
    if module:
        q = q.filter(POSSale.module == module)
    if from_date:
        q = q.filter(POSSale.created_at >= from_date)
    if to_date:
        q = q.filter(POSSale.created_at < to_date)

    sales = q.order_by(POSSale.created_at.desc()).offset(skip).limit(limit).all()
    return [_attach_items(db, sale) for sale in sales]


@router.get("/{sale_id}", response_model=POSSaleResponse)
def get_pos_sale(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    sale = db.query(POSSale).filter(POSSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="POS sale not found")
    ensure_pos_sale_access(sale, current_user)
    return _attach_items(db, sale)


@router.post("/{sale_id}/reverse", response_model=POSSaleResponse)
def reverse_pos_sale(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    sale = db.query(POSSale).filter(POSSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="POS sale not found")
    require_permission(current_user, "pos_sales", "reverse", detail="You do not have permission to reverse POS sales")
    return _attach_items(db, reverse_pos_sale_service(db, sale, current_user))
