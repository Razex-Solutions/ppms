from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, require_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.user import User
from app.models.role import Role
from app.models.station import Station
from app.schemas.user import UserCreate, UserUpdate, UserResponse
from app.core.security import hash_password

router = APIRouter(prefix="/users", tags=["Users"])
@router.post("/", response_model=UserResponse)
def create_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)

    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already exists")

    if user_data.email:
        existing_email = db.query(User).filter(User.email == user_data.email).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email already exists")

    role = db.query(Role).filter(Role.id == user_data.role_id).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")

    station = None
    organization_id = user_data.organization_id
    if user_data.station_id is not None:
        station = db.query(Station).filter(Station.id == user_data.station_id).first()
        if not station:
            raise HTTPException(status_code=404, detail="Station not found")
        if organization_id is not None and station.organization_id != organization_id:
            raise HTTPException(status_code=400, detail="Station does not belong to the provided organization")
        organization_id = station.organization_id
    elif organization_id is None and not user_data.is_platform_user:
        organization_id = get_user_organization_id(current_user)

    user = User(
        full_name=user_data.full_name,
        username=user_data.username,
        email=user_data.email,
        hashed_password=hash_password(user_data.password),
        is_active=True,
        role_id=user_data.role_id,
        organization_id=organization_id,
        station_id=user_data.station_id,
        created_by_user_id=current_user.id,
        scope_level=user_data.scope_level,
        is_platform_user=user_data.is_platform_user,
        monthly_salary=user_data.monthly_salary,
        payroll_enabled=user_data.payroll_enabled,
    )

    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/", response_model=list[UserResponse])
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    role_id: int | None = Query(None),
    is_active: bool | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    q = db.query(User)
    if current_user.role.name in {"Admin", "MasterAdmin"} or current_user.is_platform_user:
        if organization_id is not None:
            q = q.filter(User.organization_id == organization_id)
    elif is_head_office_user(current_user):
        require_permission(current_user, "users", "read", detail="You do not have permission to view users")
        user_organization_id = get_user_organization_id(current_user)
        q = q.outerjoin(Station, Station.id == User.station_id).filter(
            or_(User.organization_id == user_organization_id, Station.organization_id == user_organization_id)
        )
        if organization_id is not None and organization_id != user_organization_id:
            raise HTTPException(status_code=403, detail="Not authorized for this organization")
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != user_organization_id:
                raise HTTPException(status_code=403, detail="Not authorized for this station")
    else:
        raise HTTPException(status_code=403, detail="Admin access required")
    if station_id:
        q = q.filter(User.station_id == station_id)
    if role_id:
        q = q.filter(User.role_id == role_id)
    if is_active is not None:
        q = q.filter(User.is_active == is_active)
    users = q.offset(skip).limit(limit).all()
    return users


@router.get("/{user_id}", response_model=UserResponse)
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if current_user.role.name in {"Admin", "MasterAdmin"} or current_user.is_platform_user:
        pass
    elif is_head_office_user(current_user):
        require_permission(current_user, "users", "read", detail="You do not have permission to view users")
        user_organization_id = user.organization_id or (user.station.organization_id if user.station else None)
        if user_organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this user")
    else:
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: int,
    data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    updates = data.model_dump(exclude_unset=True)
    if "station_id" in updates:
        station_id = updates["station_id"]
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station:
                raise HTTPException(status_code=404, detail="Station not found")
            organization_id = updates.get("organization_id", user.organization_id)
            if organization_id is not None and station.organization_id != organization_id:
                raise HTTPException(status_code=400, detail="Station does not belong to the provided organization")
            updates["organization_id"] = station.organization_id
    elif "organization_id" not in updates and user.station_id is not None:
        updates["organization_id"] = user.organization_id
    for field, value in updates.items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}")
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return {"message": "User deleted"}
