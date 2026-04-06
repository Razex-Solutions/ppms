from datetime import time

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.station import Station
from app.models.station_shift_template import StationShiftTemplate
from app.models.user import User
from app.schemas.station_shift_template import (
    StationShiftTemplateCreate,
    StationShiftTemplateResponse,
    StationShiftTemplateUpdate,
)

router = APIRouter(prefix="/stations/{station_id}/shift-templates", tags=["Station Shift Templates"])


def _ensure_station_access(
    *,
    station: Station,
    current_user: User,
    write: bool = False,
) -> None:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        if write:
            require_admin(current_user)
        return
    if is_head_office_user(current_user):
        require_permission(current_user, "stations", "read", detail="You do not have permission to view shift setup")
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        if write:
            raise HTTPException(status_code=403, detail="Only admins can manage shift setup")
        return
    if current_user.station_id != station.id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    if write:
        raise HTTPException(status_code=403, detail="Only admins can manage shift setup")


def _format_window_label(start_time: time, end_time: time) -> str:
    start_label = start_time.strftime("%H:%M")
    end_label = end_time.strftime("%H:%M")
    if start_time == end_time:
        return f"{start_label} - {end_label} (24h)"
    return f"{start_label} - {end_label}"


def _serialize_template(template: StationShiftTemplate) -> dict[str, object]:
    return {
        "id": template.id,
        "station_id": template.station_id,
        "name": template.name,
        "start_time": template.start_time,
        "end_time": template.end_time,
        "is_active": template.is_active,
        "covers_full_day": template.start_time == template.end_time,
        "window_label": _format_window_label(template.start_time, template.end_time),
        "created_at": template.created_at,
    }


def _validate_window(*, start_time: time, end_time: time) -> None:
    if start_time == end_time:
        return


def _get_station(db: Session, station_id: int) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    return station


@router.get("/", response_model=list[StationShiftTemplateResponse])
def list_station_shift_templates(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    station = _get_station(db, station_id)
    _ensure_station_access(station=station, current_user=current_user)
    templates = (
        db.query(StationShiftTemplate)
        .filter(StationShiftTemplate.station_id == station_id)
        .order_by(StationShiftTemplate.start_time.asc(), StationShiftTemplate.id.asc())
        .all()
    )
    return [_serialize_template(template) for template in templates]


@router.post("/", response_model=StationShiftTemplateResponse)
def create_station_shift_template(
    station_id: int,
    data: StationShiftTemplateCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    station = _get_station(db, station_id)
    _ensure_station_access(station=station, current_user=current_user, write=True)
    _validate_window(start_time=data.start_time, end_time=data.end_time)

    duplicate = (
        db.query(StationShiftTemplate)
        .filter(
            StationShiftTemplate.station_id == station_id,
            StationShiftTemplate.name == data.name,
        )
        .first()
    )
    if duplicate:
        raise HTTPException(status_code=400, detail="A shift template with this name already exists for the station")

    template = StationShiftTemplate(station_id=station_id, **data.model_dump())
    db.add(template)
    db.commit()
    db.refresh(template)
    return _serialize_template(template)


@router.put("/{template_id}", response_model=StationShiftTemplateResponse)
def update_station_shift_template(
    station_id: int,
    template_id: int,
    data: StationShiftTemplateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    station = _get_station(db, station_id)
    _ensure_station_access(station=station, current_user=current_user, write=True)
    template = (
        db.query(StationShiftTemplate)
        .filter(
            StationShiftTemplate.id == template_id,
            StationShiftTemplate.station_id == station_id,
        )
        .first()
    )
    if not template:
        raise HTTPException(status_code=404, detail="Shift template not found")

    updates = data.model_dump(exclude_unset=True)
    next_start_time = updates.get("start_time", template.start_time)
    next_end_time = updates.get("end_time", template.end_time)
    _validate_window(start_time=next_start_time, end_time=next_end_time)

    next_name = updates.get("name")
    if next_name and next_name != template.name:
        duplicate = (
            db.query(StationShiftTemplate)
            .filter(
                StationShiftTemplate.station_id == station_id,
                StationShiftTemplate.name == next_name,
                StationShiftTemplate.id != template_id,
            )
            .first()
        )
        if duplicate:
            raise HTTPException(status_code=400, detail="A shift template with this name already exists for the station")

    for field, value in updates.items():
        setattr(template, field, value)

    db.commit()
    db.refresh(template)
    return _serialize_template(template)


@router.delete("/{template_id}")
def delete_station_shift_template(
    station_id: int,
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    station = _get_station(db, station_id)
    _ensure_station_access(station=station, current_user=current_user, write=True)
    template = (
        db.query(StationShiftTemplate)
        .filter(
            StationShiftTemplate.id == template_id,
            StationShiftTemplate.station_id == station_id,
        )
        .first()
    )
    if not template:
        raise HTTPException(status_code=404, detail="Shift template not found")
    if template.shifts:
        raise HTTPException(status_code=400, detail="Cannot delete a shift template that is already linked to shifts")

    db.delete(template)
    db.commit()
    return {"detail": "Shift template deleted"}
