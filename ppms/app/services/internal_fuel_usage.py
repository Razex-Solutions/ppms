from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.models.fuel_type import FuelType
from app.models.internal_fuel_usage import InternalFuelUsage
from app.models.tank import Tank
from app.models.user import User
from app.schemas.internal_fuel_usage import InternalFuelUsageCreate
from app.services.audit import log_audit_event


def ensure_internal_fuel_usage_access(record: InternalFuelUsage, current_user: User) -> None:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return
    if is_head_office_user(current_user):
        if record.station.organization_id == get_user_organization_id(current_user):
            return
        raise HTTPException(status_code=403, detail="Not authorized for this internal fuel usage record")
    if current_user.station_id != record.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this internal fuel usage record")


def create_internal_fuel_usage(
    db: Session,
    data: InternalFuelUsageCreate,
    current_user: User,
) -> InternalFuelUsage:
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")

    if current_user.role.name != "Admin" and not is_master_admin(current_user) and current_user.station_id != tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank")

    fuel_type = db.query(FuelType).filter(FuelType.id == data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    if tank.fuel_type_id != data.fuel_type_id:
        raise HTTPException(status_code=400, detail="Tank fuel type does not match internal usage fuel type")
    if tank.current_volume < data.quantity:
        raise HTTPException(status_code=400, detail="Insufficient tank stock for internal fuel usage")

    record = InternalFuelUsage(
        station_id=tank.station_id,
        tank_id=tank.id,
        fuel_type_id=data.fuel_type_id,
        quantity=data.quantity,
        purpose=data.purpose,
        notes=data.notes,
        used_by_user_id=current_user.id,
    )
    db.add(record)
    tank.current_volume -= data.quantity
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="internal_fuel_usage",
        action="internal_fuel_usage.create",
        entity_type="internal_fuel_usage",
        entity_id=record.id,
        station_id=record.station_id,
        details={
            "tank_id": record.tank_id,
            "quantity": record.quantity,
            "purpose": record.purpose,
        },
    )
    db.commit()
    db.refresh(record)
    return record
