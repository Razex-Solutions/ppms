from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.brand_catalog import BrandCatalog
from app.models.organization import Organization
from app.models.station import Station
from app.models.user import User
from app.schemas.organization import OrganizationCreate, OrganizationResponse, OrganizationUpdate
from app.schemas.setup_foundation import OrganizationSetupFoundationResponse
from app.services.setup_foundation import build_organization_setup_foundation

router = APIRouter(prefix="/organizations", tags=["Organizations"])


def _resolve_branding(
    db: Session,
    *,
    brand_catalog_id: int | None,
    brand_name: str | None,
    brand_code: str | None,
    logo_url: str | None,
) -> dict[str, object | None]:
    payload: dict[str, object | None] = {
        "brand_catalog_id": brand_catalog_id,
        "brand_name": brand_name,
        "brand_code": brand_code,
        "logo_url": logo_url,
    }
    if brand_catalog_id is None:
        return payload

    brand = db.query(BrandCatalog).filter(BrandCatalog.id == brand_catalog_id).first()
    if not brand:
        raise HTTPException(status_code=404, detail="Brand not found")

    payload["brand_name"] = brand_name or brand.name
    payload["brand_code"] = brand_code or brand.code
    payload["logo_url"] = logo_url or brand.logo_url
    return payload


def _serialize_organization(organization: Organization) -> dict[str, object | None]:
    return {
        "id": organization.id,
        "name": organization.name,
        "code": organization.code,
        "description": organization.description,
        "legal_name": organization.legal_name,
        "brand_catalog_id": organization.brand_catalog_id,
        "brand_name": organization.brand_name,
        "brand_code": organization.brand_code,
        "logo_url": organization.logo_url,
        "contact_email": organization.contact_email,
        "contact_phone": organization.contact_phone,
        "registration_number": organization.registration_number,
        "tax_registration_number": organization.tax_registration_number,
        "onboarding_status": organization.onboarding_status,
        "billing_status": organization.billing_status,
        "station_target_count": organization.station_target_count,
        "inherit_branding_to_stations": organization.inherit_branding_to_stations,
        "is_active": organization.is_active,
    }


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

    payload = data.model_dump()
    payload.update(
        _resolve_branding(
            db,
            brand_catalog_id=payload.get("brand_catalog_id"),
            brand_name=payload.get("brand_name"),
            brand_code=payload.get("brand_code"),
            logo_url=payload.get("logo_url"),
        )
    )

    organization = Organization(**payload)
    db.add(organization)
    db.commit()
    db.refresh(organization)
    return _serialize_organization(organization)


@router.get("/", response_model=list[OrganizationResponse])
def list_organizations(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    is_active: bool | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Organization)
    if is_master_admin(current_user):
        if is_active is not None:
            query = query.filter(Organization.is_active == is_active)
        return [_serialize_organization(item) for item in query.offset(skip).limit(limit).all()]
    if is_head_office_user(current_user):
        require_permission(current_user, "organizations", "read", detail="You do not have permission to view organizations")
        query = query.filter(Organization.id == get_user_organization_id(current_user))
        if is_active is not None:
            query = query.filter(Organization.is_active == is_active)
        return [_serialize_organization(item) for item in query.offset(skip).limit(limit).all()]
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
    if is_master_admin(current_user):
        return _serialize_organization(organization)
    if is_head_office_user(current_user):
        require_permission(current_user, "organizations", "read", detail="You do not have permission to view organizations")
        if organization.id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this organization")
        return _serialize_organization(organization)
    raise HTTPException(status_code=403, detail="Admin access required")


@router.get("/{organization_id}/setup-foundation", response_model=OrganizationSetupFoundationResponse)
def get_organization_setup_foundation(
    organization_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if is_master_admin(current_user):
        return build_organization_setup_foundation(db, organization)
    if is_head_office_user(current_user):
        require_permission(current_user, "organizations", "read", detail="You do not have permission to view organizations")
        if organization.id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this organization")
        return build_organization_setup_foundation(db, organization)
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
    updates = data.model_dump(exclude_unset=True)
    updates.update(
        _resolve_branding(
            db,
            brand_catalog_id=updates.get("brand_catalog_id", organization.brand_catalog_id),
            brand_name=updates.get("brand_name", organization.brand_name),
            brand_code=updates.get("brand_code", organization.brand_code),
            logo_url=updates.get("logo_url", organization.logo_url),
        )
    )
    for field, value in updates.items():
        setattr(organization, field, value)
    db.commit()
    db.refresh(organization)
    return _serialize_organization(organization)


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
