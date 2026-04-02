from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.pos_product import POSProduct
from app.models.pos_sale_item import POSSaleItem
from app.models.user import User
from app.schemas.pos_product import POSProductCreate, POSProductResponse, POSProductUpdate
from app.services.pos import create_pos_product as create_pos_product_service
from app.services.pos import update_pos_product as update_pos_product_service

router = APIRouter(prefix="/pos-products", tags=["POS Products"])


@router.post("/", response_model=POSProductResponse)
def create_pos_product(
    data: POSProductCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return create_pos_product_service(db, data, current_user)


@router.get("/", response_model=list[POSProductResponse])
def list_pos_products(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    module: str | None = Query(None),
    is_active: bool | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(POSProduct)
    if station_id:
        q = q.filter(POSProduct.station_id == station_id)
    if module:
        q = q.filter(POSProduct.module == module)
    if is_active is not None:
        q = q.filter(POSProduct.is_active == is_active)
    return q.offset(skip).limit(limit).all()


@router.get("/{product_id}", response_model=POSProductResponse)
def get_pos_product(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    product = db.query(POSProduct).filter(POSProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="POS product not found")
    require_station_access(current_user, product.station_id, detail="Not authorized for this POS product")
    return product


@router.put("/{product_id}", response_model=POSProductResponse)
def update_pos_product(
    product_id: int,
    data: POSProductUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    product = db.query(POSProduct).filter(POSProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="POS product not found")
    require_station_access(current_user, product.station_id, detail="Not authorized for this POS product")
    return update_pos_product_service(db, product, data)


@router.delete("/{product_id}")
def delete_pos_product(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    product = db.query(POSProduct).filter(POSProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="POS product not found")
    require_station_access(current_user, product.station_id, detail="Not authorized for this POS product")
    if db.query(POSSaleItem).filter(POSSaleItem.product_id == product.id).first():
        raise HTTPException(status_code=400, detail="POS product cannot be deleted while sale history exists")
    db.delete(product)
    db.commit()
    return {"message": "POS product deleted"}
