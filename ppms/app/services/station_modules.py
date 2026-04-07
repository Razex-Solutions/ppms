from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_master_admin
from app.models.station import Station
from app.models.station_module_setting import StationModuleSetting
from app.models.user import User


def is_station_module_enabled(db: Session, station_id: int, module_name: str) -> bool:
    setting = db.query(StationModuleSetting).filter(
        StationModuleSetting.station_id == station_id,
        StationModuleSetting.module_name == module_name,
    ).first()
    return bool(setting and setting.is_enabled)


def require_station_module_enabled(db: Session, station_id: int, module_name: str) -> None:
    if not is_station_module_enabled(db, station_id, module_name):
        raise HTTPException(status_code=403, detail=f"{module_name} module is not enabled for this station")


def ensure_station_module_access(db: Session, station_id: int, current_user: User) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return station
    if current_user.role.name == "HeadOffice":
        user_organization_id = get_user_organization_id(current_user)
        if station.organization_id != user_organization_id:
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        return station
    if current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    return station


def set_station_module(db: Session, station_id: int, module_name: str, is_enabled: bool) -> StationModuleSetting:
    setting = db.query(StationModuleSetting).filter(
        StationModuleSetting.station_id == station_id,
        StationModuleSetting.module_name == module_name,
    ).first()
    if setting is None:
        setting = StationModuleSetting(station_id=station_id, module_name=module_name, is_enabled=is_enabled)
        db.add(setting)
    else:
        setting.is_enabled = is_enabled
    db.commit()
    db.refresh(setting)
    return setting
