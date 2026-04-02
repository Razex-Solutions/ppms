from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.purchase import Purchase
from app.models.supplier import Supplier
from app.models.tank import Tank
from app.models.fuel_type import FuelType
from app.models.tanker import Tanker
from app.schemas.purchase import PurchaseCreate, PurchaseResponse

router = APIRouter(prefix="/purchases", tags=["Purchases"])


def _ensure_purchase_access(purchase: Purchase, current_user) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != purchase.tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this purchase")


@router.post("/", response_model=PurchaseResponse)
def create_purchase(
    data: PurchaseCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank")

    supplier = db.query(Supplier).filter(Supplier.id == data.supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")

    fuel_type = db.query(FuelType).filter(FuelType.id == data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")

    if data.tanker_id is not None:
        tanker = db.query(Tanker).filter(Tanker.id == data.tanker_id).first()
        if not tanker:
            raise HTTPException(status_code=404, detail="Tanker not found")

    if tank.fuel_type_id != data.fuel_type_id:
        raise HTTPException(
            status_code=400,
            detail="Tank fuel type does not match purchase fuel type"
        )

    if data.quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be greater than 0")

    if data.rate_per_liter <= 0:
        raise HTTPException(status_code=400, detail="Rate per liter must be greater than 0")

    if tank.current_volume + data.quantity > tank.capacity:
        raise HTTPException(status_code=400, detail="Tank capacity exceeded")

    total_amount = data.quantity * data.rate_per_liter

    purchase = Purchase(
        supplier_id=data.supplier_id,
        tank_id=data.tank_id,
        fuel_type_id=data.fuel_type_id,
        tanker_id=data.tanker_id,
        quantity=data.quantity,
        rate_per_liter=data.rate_per_liter,
        total_amount=total_amount,
        reference_no=data.reference_no,
        notes=data.notes
    )

    db.add(purchase)

    # update tank stock
    tank.current_volume += data.quantity

    # update tanker status if linked
    if data.tanker_id:
        tanker = db.query(Tanker).filter(Tanker.id == data.tanker_id).first()
        if tanker:
            tanker.status = "active"  # Assuming tanker is now at station/active after delivery

    # update supplier payable balance
    supplier.payable_balance += total_amount

    db.commit()
    db.refresh(purchase)
    return purchase


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

    _ensure_purchase_access(purchase, current_user)

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

    _ensure_purchase_access(purchase, current_user)

    if purchase.is_reversed:
        raise HTTPException(status_code=400, detail="Purchase is already reversed")

    tank = db.query(Tank).filter(Tank.id == purchase.tank_id).first()
    supplier = db.query(Supplier).filter(Supplier.id == purchase.supplier_id).first()
    if tank is None or supplier is None:
        raise HTTPException(status_code=400, detail="Cannot reverse purchase because related records are missing")

    if tank.current_volume < purchase.quantity:
        raise HTTPException(status_code=400, detail="Purchase cannot be reversed because stock has already been consumed")

    if supplier.payable_balance < purchase.total_amount:
        raise HTTPException(status_code=400, detail="Purchase cannot be reversed after supplier balance has been settled")

    tank.current_volume -= purchase.quantity
    supplier.payable_balance -= purchase.total_amount
    purchase.is_reversed = True
    purchase.reversed_at = datetime.utcnow()
    purchase.reversed_by = current_user.id

    db.commit()
    db.refresh(purchase)
    return purchase
