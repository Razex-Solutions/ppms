from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.tank import Tank
from app.models.tank_dip import TankDip
from app.models.user import User
from app.schemas.tank_dip import TankDipCreate


def create_tank_dip(db: Session, data: TankDipCreate, current_user: User) -> TankDip:
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    if current_user.role.name != "Admin" and current_user.station_id != tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank")

    system_volume = tank.current_volume
    dip = TankDip(
        tank_id=data.tank_id,
        dip_reading_mm=data.dip_reading_mm,
        calculated_volume=data.calculated_volume,
        system_volume=system_volume,
        loss_gain=data.calculated_volume - system_volume,
        notes=data.notes,
    )
    db.add(dip)
    tank.current_volume = data.calculated_volume
    db.commit()
    db.refresh(dip)
    return dip


def ensure_tank_dip_access(dip: TankDip, current_user: User) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != dip.tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank dip")
