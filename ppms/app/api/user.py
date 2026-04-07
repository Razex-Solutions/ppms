from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.core.permissions import ensure_role_creation_allowed, get_role_scope_rule
from app.models.user import User
from app.models.role import Role
from app.models.station import Station
from app.schemas.user import UserCreate, UserUpdate, UserResponse
from app.core.security import hash_password

router = APIRouter(prefix="/users", tags=["Users"])


def _normalize_user_scope(
    *,
    current_user: User,
    role_name: str,
    requested_organization_id: int | None,
    requested_station_id: int | None,
    requested_scope_level: str | None,
    requested_platform_user: bool,
    db: Session,
    existing_user: User | None = None,
) -> tuple[int | None, int | None, str, bool]:
    scope_rule = get_role_scope_rule(role_name)
    station = None
    organization_id = requested_organization_id
    station_id = requested_station_id

    if station_id is not None:
        station = db.query(Station).filter(Station.id == station_id).first()
        if not station:
            raise HTTPException(status_code=404, detail="Station not found")
        if organization_id is not None and station.organization_id != organization_id:
            raise HTTPException(status_code=400, detail="Station does not belong to the provided organization")
        organization_id = station.organization_id

    if scope_rule["platform_only"]:
        if not (current_user.role.name == "MasterAdmin" or current_user.is_platform_user):
            raise HTTPException(status_code=403, detail="Only platform users can assign platform roles")
        return None, None, "platform", True

    if scope_rule["requires_organization"] and organization_id is None:
        organization_id = existing_user.organization_id if existing_user else get_user_organization_id(current_user)
    if scope_rule["requires_organization"] and organization_id is None:
        raise HTTPException(status_code=400, detail=f"Role '{role_name}' requires an organization assignment")

    if scope_rule["requires_station"] and station_id is None:
        station_id = existing_user.station_id if existing_user else None
    if scope_rule["requires_station"] and station_id is None:
        raise HTTPException(status_code=400, detail=f"Role '{role_name}' requires a station assignment")

    if not scope_rule["requires_station"]:
        station_id = None

    if current_user.role.name not in {"MasterAdmin", "Admin"} and not current_user.is_platform_user:
        current_org_id = get_user_organization_id(current_user)
        if organization_id != current_org_id:
            raise HTTPException(status_code=403, detail="You can only manage users inside your organization")
    elif current_user.role.name == "Admin" and organization_id is not None:
        current_org_id = get_user_organization_id(current_user)
        if current_org_id is not None and organization_id != current_org_id:
            raise HTTPException(status_code=403, detail="Admin can only manage users inside the assigned organization")

    normalized_scope_level = str(scope_rule["scope_level"])
    if requested_scope_level and requested_scope_level != normalized_scope_level:
        normalized_scope_level = str(scope_rule["scope_level"])

    return organization_id, station_id, normalized_scope_level, False
@router.post("/", response_model=UserResponse)
def create_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
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
    ensure_role_creation_allowed(current_user, role.name)

    organization_id, station_id, scope_level, is_platform_user = _normalize_user_scope(
        current_user=current_user,
        role_name=role.name,
        requested_organization_id=user_data.organization_id,
        requested_station_id=user_data.station_id,
        requested_scope_level=user_data.scope_level,
        requested_platform_user=user_data.is_platform_user,
        db=db,
    )

    user = User(
        full_name=user_data.full_name,
        username=user_data.username,
        email=user_data.email,
        hashed_password=hash_password(user_data.password),
        is_active=True,
        role_id=user_data.role_id,
        organization_id=organization_id,
        station_id=station_id,
        created_by_user_id=current_user.id,
        scope_level=scope_level,
        is_platform_user=is_platform_user,
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
    if is_master_admin(current_user):
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
        require_permission(current_user, "users", "read", detail="You do not have permission to view users")
        if current_user.station_id is None:
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        if station_id is not None and station_id != current_user.station_id:
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        if organization_id is not None and organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this organization")
        q = q.filter(User.station_id == current_user.station_id)
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
    if is_master_admin(current_user):
        pass
    elif is_head_office_user(current_user):
        require_permission(current_user, "users", "read", detail="You do not have permission to view users")
        user_organization_id = user.organization_id or (user.station.organization_id if user.station else None)
        if user_organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this user")
    else:
        require_permission(current_user, "users", "read", detail="You do not have permission to view users")
        if current_user.station_id != user.station_id:
            raise HTTPException(status_code=403, detail="Not authorized for this user")
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
    target_role = user.role
    if "role_id" in updates:
        target_role = db.query(Role).filter(Role.id == updates["role_id"]).first()
        if not target_role:
            raise HTTPException(status_code=404, detail="Role not found")
        ensure_role_creation_allowed(current_user, target_role.name)
    organization_id, station_id, scope_level, is_platform_user = _normalize_user_scope(
        current_user=current_user,
        role_name=target_role.name,
        requested_organization_id=updates.get("organization_id", user.organization_id),
        requested_station_id=updates.get("station_id", user.station_id),
        requested_scope_level=updates.get("scope_level", user.scope_level),
        requested_platform_user=updates.get("is_platform_user", user.is_platform_user),
        db=db,
        existing_user=user,
    )
    updates["organization_id"] = organization_id
    updates["station_id"] = station_id
    updates["scope_level"] = scope_level
    updates["is_platform_user"] = is_platform_user
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
