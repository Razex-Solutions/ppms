from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.models.tank import Tank
from app.models.tank_dip import TankDip
from app.models.user import User
from app.schemas.tank_dip import TankDipCreate
from app.services.tank_calibrations import calculate_tank_volume_from_dip_mm


def create_tank_dip(db: Session, data: TankDipCreate, current_user: User) -> TankDip:
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    if not is_master_admin(current_user) and current_user.station_id != tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank")

    system_volume = tank.current_volume
    calculated_volume = calculate_tank_volume_from_dip_mm(db, tank_id=data.tank_id, dip_reading_mm=data.dip_reading_mm)
    dip = TankDip(
        tank_id=data.tank_id,
        dip_reading_mm=data.dip_reading_mm,
        calculated_volume=calculated_volume,
        system_volume=system_volume,
        loss_gain=calculated_volume - system_volume,
        notes=data.notes,
    )
    db.add(dip)
    tank.current_volume = calculated_volume
    db.commit()
    db.refresh(dip)
    return dip


def ensure_tank_dip_access(dip: TankDip, current_user: User) -> None:
    if not is_master_admin(current_user) and current_user.station_id != dip.tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank dip")
