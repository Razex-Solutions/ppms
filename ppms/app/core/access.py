from fastapi import HTTPException

from app.models.user import User


def require_admin(current_user: User) -> None:
    if current_user.role.name != "Admin":
        raise HTTPException(status_code=403, detail="Admin access required")


def require_station_access(current_user: User, station_id: int, detail: str = "Not authorized for this station") -> None:
    if current_user.role.name != "Admin" and current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail=detail)
