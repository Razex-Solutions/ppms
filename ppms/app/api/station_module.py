from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.station_module_setting import StationModuleSetting
from app.models.user import User
from app.schemas.station_module_setting import StationModuleSettingResponse, StationModuleSettingUpdate
from app.services.audit import log_audit_event
from app.services.station_modules import ensure_station_module_access, set_station_module

router = APIRouter(prefix="/station-modules", tags=["Station Modules"])


@router.get("/{station_id}", response_model=list[StationModuleSettingResponse])
def list_station_modules(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "station_modules", "read", detail="You do not have permission to view station modules")
    ensure_station_module_access(db, station_id, current_user)
    return db.query(StationModuleSetting).filter(StationModuleSetting.station_id == station_id).all()


@router.put("/{station_id}", response_model=StationModuleSettingResponse)
def update_station_module(
    station_id: int,
    data: StationModuleSettingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "station_modules", "update", detail="You do not have permission to update station modules")
    ensure_station_module_access(db, station_id, current_user)
    setting = set_station_module(db, station_id, data.module_name, data.is_enabled)
    log_audit_event(
        db,
        current_user=current_user,
        module="station_modules",
        action="station_modules.update",
        entity_type="station_module_setting",
        entity_id=setting.id,
        station_id=station_id,
        details={"module_name": data.module_name, "is_enabled": data.is_enabled},
    )
    db.commit()
    db.refresh(setting)
    return setting
