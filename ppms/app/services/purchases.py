from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models.fuel_type import FuelType
from app.models.purchase import Purchase
from app.models.supplier import Supplier
from app.models.tank import Tank
from app.models.tanker import Tanker
from app.models.user import User
from app.schemas.purchase import PurchaseCreate
from app.services.audit import log_audit_event


def ensure_purchase_access(purchase: Purchase, current_user: User) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != purchase.tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this purchase")


def create_purchase(db: Session, data: PurchaseCreate, current_user: User) -> Purchase:
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    if current_user.role.name != "Admin" and current_user.station_id != tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank")

    supplier = db.query(Supplier).filter(Supplier.id == data.supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    fuel_type = db.query(FuelType).filter(FuelType.id == data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")

    tanker = None
    if data.tanker_id is not None:
        tanker = db.query(Tanker).filter(Tanker.id == data.tanker_id).first()
        if not tanker:
            raise HTTPException(status_code=404, detail="Tanker not found")

    if tank.fuel_type_id != data.fuel_type_id:
        raise HTTPException(status_code=400, detail="Tank fuel type does not match purchase fuel type")
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
        notes=data.notes,
    )
    db.add(purchase)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.create",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=tank.station_id,
        details={"total_amount": total_amount, "quantity": data.quantity},
    )
    tank.current_volume += data.quantity
    if tanker:
        tanker.status = "active"
    supplier.payable_balance += total_amount
    db.commit()
    db.refresh(purchase)
    return purchase


def reverse_purchase(db: Session, purchase: Purchase, current_user: User) -> Purchase:
    ensure_purchase_access(purchase, current_user)
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
    purchase.reversed_at = utc_now()
    purchase.reversed_by = current_user.id
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.reverse",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=tank.station_id,
        details={"total_amount": purchase.total_amount, "quantity": purchase.quantity},
    )
    db.commit()
    db.refresh(purchase)
    return purchase
