from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.fuel_sale import FuelSale
from app.schemas.fuel_sale import FuelSaleCreate, FuelSaleResponse
from app.services.fuel_sales import create_fuel_sale as create_fuel_sale_service
from app.services.fuel_sales import ensure_sale_access, reverse_fuel_sale as reverse_fuel_sale_service

router = APIRouter(prefix="/fuel-sales", tags=["Fuel Sales"])


@router.post("/", response_model=FuelSaleResponse)
def create_fuel_sale(
    sale_data: FuelSaleCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    return create_fuel_sale_service(db, sale_data, current_user)


@router.get("/{sale_id}", response_model=FuelSaleResponse)
def get_fuel_sale(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    sale = db.query(FuelSale).filter(FuelSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Fuel sale not found")

    ensure_sale_access(sale, current_user)
    return sale


@router.post("/{sale_id}/reverse", response_model=FuelSaleResponse)
def reverse_fuel_sale(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    sale = db.query(FuelSale).filter(FuelSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Fuel sale not found")

    return reverse_fuel_sale_service(db, sale, current_user)


@router.get("/", response_model=list[FuelSaleResponse])
def list_fuel_sales(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    customer_id: int | None = Query(None),
    fuel_type_id: int | None = Query(None),
    sale_type: str | None = Query(None, description="cash or credit"),
    shift_name: str | None = Query(None),
    shift_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    q = db.query(FuelSale)
    
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id
        
    if station_id:
        q = q.filter(FuelSale.station_id == station_id)
    if customer_id:
        q = q.filter(FuelSale.customer_id == customer_id)
    if fuel_type_id:
        q = q.filter(FuelSale.fuel_type_id == fuel_type_id)
    if sale_type:
        q = q.filter(FuelSale.sale_type == sale_type)
    if shift_name:
        q = q.filter(FuelSale.shift_name == shift_name)
    if shift_id:
        q = q.filter(FuelSale.shift_id == shift_id)
    if from_date:
        q = q.filter(FuelSale.created_at >= from_date)
    if to_date:
        q = q.filter(FuelSale.created_at < to_date)
    return q.order_by(FuelSale.created_at.desc()).offset(skip).limit(limit).all()
