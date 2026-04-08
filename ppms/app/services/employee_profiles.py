from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_station_access
from app.models.employee_profile import EmployeeProfile
from app.models.station import Station
from app.models.user import User
from app.schemas.employee_profile import EmployeeProfileCreate, EmployeeProfileUpdate


def ensure_employee_profile_access(db: Session, station_id: int, current_user: User) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if is_master_admin(current_user):
        return station
    if is_head_office_user(current_user):
        if station.organization_id == get_user_organization_id(current_user):
            return station
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    require_station_access(current_user, station_id)
    return station


def validate_linked_user(db: Session, *, linked_user_id: int | None, station_id: int, organization_id: int) -> User | None:
    if linked_user_id is None:
        return None
    user = db.query(User).filter(User.id == linked_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Linked user not found")
    if user.station_id != station_id or user.organization_id != organization_id:
        raise HTTPException(status_code=400, detail="Linked user must belong to the same station and organization")
    return user


def resolve_staff_title(*, staff_type: str | None, staff_title: str | None) -> tuple[str, str]:
    resolved_title = (staff_title or staff_type or "").strip()
    if not resolved_title:
        raise HTTPException(status_code=400, detail="Staff title is required")
    return resolved_title, resolved_title


def create_employee_profile(db: Session, *, data: EmployeeProfileCreate, current_user: User) -> EmployeeProfile:
    station = ensure_employee_profile_access(db, data.station_id, current_user)
    validate_linked_user(db, linked_user_id=data.linked_user_id, station_id=station.id, organization_id=station.organization_id)
    if data.can_login and data.linked_user_id is None:
        raise HTTPException(status_code=400, detail="Linked user is required when login access is enabled")
    staff_type, staff_title = resolve_staff_title(staff_type=data.staff_type, staff_title=data.staff_title)
    payload = data.model_dump()
    payload["staff_type"] = staff_type
    payload["staff_title"] = staff_title
    profile = EmployeeProfile(
        organization_id=station.organization_id,
        **payload,
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


def update_employee_profile(
    db: Session,
    *,
    profile: EmployeeProfile,
    data: EmployeeProfileUpdate,
    current_user: User,
) -> EmployeeProfile:
    updates = data.model_dump(exclude_unset=True)
    station_id = updates.get("station_id", profile.station_id)
    station = ensure_employee_profile_access(db, station_id, current_user)
    linked_user_id = updates.get("linked_user_id", profile.linked_user_id)
    validate_linked_user(db, linked_user_id=linked_user_id, station_id=station.id, organization_id=station.organization_id)
    can_login = updates.get("can_login", profile.can_login)
    if can_login and linked_user_id is None:
        raise HTTPException(status_code=400, detail="Linked user is required when login access is enabled")
    if "staff_type" in updates or "staff_title" in updates:
        staff_type, staff_title = resolve_staff_title(
            staff_type=updates.get("staff_type", profile.staff_type),
            staff_title=updates.get("staff_title", profile.staff_title or profile.staff_type),
        )
        updates["staff_type"] = staff_type
        updates["staff_title"] = staff_title
    updates["organization_id"] = station.organization_id
    for field, value in updates.items():
        setattr(profile, field, value)
    db.commit()
    db.refresh(profile)
    return profile
