from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, require_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.organization import Organization
from app.models.station import Station
from app.models.user import User
from app.schemas.organization import OrganizationCreate, OrganizationResponse, OrganizationUpdate

router = APIRouter(prefix="/organizations", tags=["Organizations"])


@router.post("/", response_model=OrganizationResponse)
def create_organization(
    data: OrganizationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    existing = db.query(Organization).filter(Organization.code == data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Organization code already exists")

    organization = Organization(**data.model_dump())
    db.add(organization)
    db.commit()
    db.refresh(organization)
    return organization


@router.get("/", response_model=list[OrganizationResponse])
def list_organizations(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    is_active: bool | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Organization)
    if current_user.role.name == "Admin":
        if is_active is not None:
            query = query.filter(Organization.is_active == is_active)
        return query.offset(skip).limit(limit).all()
    if is_head_office_user(current_user):
        require_permission(current_user, "organizations", "read", detail="You do not have permission to view organizations")
        query = query.filter(Organization.id == get_user_organization_id(current_user))
        if is_active is not None:
            query = query.filter(Organization.is_active == is_active)
        return query.offset(skip).limit(limit).all()
    raise HTTPException(status_code=403, detail="Admin access required")


@router.get("/{organization_id}", response_model=OrganizationResponse)
def get_organization(
    organization_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if current_user.role.name == "Admin":
        return organization
    if is_head_office_user(current_user):
        require_permission(current_user, "organizations", "read", detail="You do not have permission to view organizations")
        if organization.id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this organization")
        return organization
    raise HTTPException(status_code=403, detail="Admin access required")


@router.put("/{organization_id}", response_model=OrganizationResponse)
def update_organization(
    organization_id: int,
    data: OrganizationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(organization, field, value)
    db.commit()
    db.refresh(organization)
    return organization


@router.delete("/{organization_id}")
def delete_organization(
    organization_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if db.query(Station).filter(Station.organization_id == organization.id).first():
        raise HTTPException(status_code=400, detail="Organization cannot be deleted while stations are assigned to it")
    db.delete(organization)
    db.commit()
    return {"message": "Organization deleted"}
