from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import (
    ROLE_CAPABILITY_SUMMARY,
    ensure_core_role_mutation_allowed,
    get_permission_catalog,
    get_role_permissions,
    require_permission,
)
from app.models.role import Role
from app.models.user import User
from app.schemas.role import (
    PermissionCatalogResponse,
    RoleCreate,
    RolePermissionResponse,
    RoleResponse,
    RoleUpdate,
)

router = APIRouter(prefix="/roles", tags=["Roles"])


@router.get("/permission-catalog", response_model=PermissionCatalogResponse)
def get_roles_permission_catalog(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "roles", "read", detail="You do not have permission to view role policy data")
    return get_permission_catalog()


@router.get("/permission-catalog/{role_name}", response_model=RolePermissionResponse)
def get_role_permission_summary(
    role_name: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "roles", "read", detail="You do not have permission to view role policy data")
    return RolePermissionResponse(
        role_name=role_name,
        summary=ROLE_CAPABILITY_SUMMARY.get(role_name),
        permissions=get_role_permissions(role_name),
    )


@router.post("/", response_model=RoleResponse)
def create_role(role_data: RoleCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_permission(current_user, "roles", "create", detail="You do not have permission to create roles")

    existing_role = db.query(Role).filter(Role.name == role_data.name).first()
    if existing_role:
        raise HTTPException(status_code=400, detail="Role already exists")

    role = Role(
        name=role_data.name,
        description=role_data.description
    )
    db.add(role)
    db.commit()
    db.refresh(role)
    return role


@router.get("/", response_model=list[RoleResponse])
def list_roles(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_permission(current_user, "roles", "read", detail="You do not have permission to view roles")
    return db.query(Role).offset(skip).limit(limit).all()


@router.get("/{role_id}", response_model=RoleResponse)
def get_role(role_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_permission(current_user, "roles", "read", detail="You do not have permission to view roles")
    role = db.query(Role).filter(Role.id == role_id).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    return role


@router.put("/{role_id}", response_model=RoleResponse)
def update_role(
    role_id: int,
    data: RoleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_permission(current_user, "roles", "update", detail="You do not have permission to update roles")
    role = db.query(Role).filter(Role.id == role_id).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    if "name" in data.model_dump(exclude_unset=True) and data.model_dump(exclude_unset=True)["name"] != role.name:
        ensure_core_role_mutation_allowed(role.name, "renamed")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(role, field, value)
    db.commit()
    db.refresh(role)
    return role


@router.delete("/{role_id}")
def delete_role(role_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    require_permission(current_user, "roles", "delete", detail="You do not have permission to delete roles")
    role = db.query(Role).filter(Role.id == role_id).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    ensure_core_role_mutation_allowed(role.name, "deleted")
    if role.users:
        raise HTTPException(status_code=400, detail="Role cannot be deleted while users are assigned to it")
    db.delete(role)
    db.commit()
    return {"message": "Role deleted"}
