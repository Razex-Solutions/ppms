from fastapi import HTTPException

from app.models.user import User


def require_admin(current_user: User) -> None:
    if current_user.role.name != "Admin":
        raise HTTPException(status_code=403, detail="Admin access required")


def get_user_organization_id(current_user: User) -> int | None:
    return current_user.station.organization_id if getattr(current_user, "station", None) else None


def is_head_office_user(current_user: User) -> bool:
    return current_user.role.name == "HeadOffice"


def require_station_access(current_user: User, station_id: int, detail: str = "Not authorized for this station") -> None:
    if current_user.role.name == "Admin":
        return
    if current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail=detail)


def require_organization_access(current_user: User, organization_id: int, detail: str = "Not authorized for this organization") -> None:
    if current_user.role.name == "Admin":
        return
    if organization_id is None:
        raise HTTPException(status_code=403, detail=detail)
    if get_user_organization_id(current_user) != organization_id:
        raise HTTPException(status_code=403, detail=detail)
