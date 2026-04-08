from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.brand_catalog import BrandCatalog
from app.models.customer import Customer
from app.models.dispenser import Dispenser
from app.models.notification import Notification
from app.models.nozzle import Nozzle
from app.models.organization import Organization
from app.models.organization_module_setting import OrganizationModuleSetting
from app.models.shift import Shift
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.tank import Tank
from app.models.user import User
from app.schemas.organization import (
    OrganizationCreate,
    OrganizationDashboardModuleStatus,
    OrganizationDashboardRoleCount,
    OrganizationDashboardSummaryResponse,
    OrganizationResponse,
    OrganizationUpdate,
)
from app.schemas.setup_foundation import (
    OrganizationOnboardingApplyRequest,
    OrganizationOnboardingApplyResponse,
    OrganizationOnboardingSummaryResponse,
    OrganizationSetupFoundationResponse,
)
from app.services.setup_foundation import (
    apply_organization_onboarding,
    build_organization_onboarding_summary,
    build_organization_setup_foundation,
)

router = APIRouter(prefix="/organizations", tags=["Organizations"])


def _require_organization_write_access(current_user: User, organization_id: int | None = None) -> None:
    if is_master_admin(current_user):
        return
    require_permission(current_user, "organizations", "update", detail="You do not have permission to manage organizations")
    if organization_id is not None and organization_id != get_user_organization_id(current_user):
        raise HTTPException(status_code=403, detail="Not authorized for this organization")


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


@router.post("/onboarding/apply", response_model=OrganizationOnboardingApplyResponse)
def apply_organization_onboarding_route(
    data: OrganizationOnboardingApplyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    return apply_organization_onboarding(db, payload=data, current_user=current_user)


@router.get("/{organization_id}/onboarding-summary", response_model=OrganizationOnboardingSummaryResponse)
def get_organization_onboarding_summary(
    organization_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if is_master_admin(current_user):
        return build_organization_onboarding_summary(db, organization)
    if is_head_office_user(current_user):
        require_permission(current_user, "organizations", "read", detail="You do not have permission to view organizations")
        if organization.id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this organization")
        return build_organization_onboarding_summary(db, organization)
    raise HTTPException(status_code=403, detail="Admin access required")


@router.put("/{organization_id}", response_model=OrganizationResponse)
def update_organization(
    organization_id: int,
    data: OrganizationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    _require_organization_write_access(current_user, organization.id)
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


@router.get("/{organization_id}/dashboard-summary", response_model=OrganizationDashboardSummaryResponse)
def get_organization_dashboard_summary(
    organization_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if not is_master_admin(current_user):
        require_permission(current_user, "organizations", "read", detail="You do not have permission to view organization dashboards")
        if organization.id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this organization")

    stations = db.query(Station).filter(Station.organization_id == organization.id).all()
    station_ids = [station.id for station in stations]
    active_station_count = sum(1 for station in stations if station.is_active)
    inactive_station_count = len(stations) - active_station_count
    completed_station_setup_count = sum(1 for station in stations if station.setup_status == "completed")
    pending_station_setup_count = len(stations) - completed_station_setup_count

    users = db.query(User).filter(User.organization_id == organization.id).all()
    role_counts = [
        OrganizationDashboardRoleCount(role_name=role_name, user_count=count)
        for role_name, count in sorted(
            {
                role_name: sum(1 for user in users if user.role and user.role.name == role_name and user.is_active)
                for role_name in {user.role.name for user in users if user.role is not None}
            }.items()
        )
    ]

    active_forecourt_tank_count = 0
    active_forecourt_dispenser_count = 0
    active_forecourt_nozzle_count = 0
    open_shift_count = 0
    pending_customer_balance_total = 0.0
    pending_supplier_balance_total = 0.0
    if station_ids:
        active_forecourt_tank_count = db.query(Tank).filter(Tank.station_id.in_(station_ids), Tank.is_active.is_(True)).count()
        active_forecourt_dispenser_count = db.query(Dispenser).filter(Dispenser.station_id.in_(station_ids), Dispenser.is_active.is_(True)).count()
        active_forecourt_nozzle_count = (
            db.query(Nozzle)
            .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
            .filter(Dispenser.station_id.in_(station_ids), Nozzle.is_active.is_(True), Dispenser.is_active.is_(True))
            .count()
        )
        open_shift_count = db.query(Shift).filter(Shift.station_id.in_(station_ids), Shift.status == "open").count()
        pending_customer_balance_total = float(
            db.query(func.coalesce(func.sum(Customer.outstanding_balance), 0.0))
            .filter(Customer.station_id.in_(station_ids))
            .scalar()
            or 0.0
        )

    pending_supplier_balance_total = float(
        db.query(func.coalesce(func.sum(Supplier.payable_balance), 0.0)).scalar() or 0.0
    )

    unread_notification_count = db.query(Notification).filter(
        Notification.organization_id == organization.id,
        Notification.is_read.is_(False),
    ).count()

    module_rows = (
        db.query(OrganizationModuleSetting)
        .filter(OrganizationModuleSetting.organization_id == organization.id)
        .order_by(OrganizationModuleSetting.module_name.asc())
        .all()
    )
    station_total = len(stations)
    module_statuses = [
        OrganizationDashboardModuleStatus(
            module_name=row.module_name,
            enabled_station_count=station_total if row.is_enabled else 0,
            total_station_count=station_total,
            fully_enabled=bool(row.is_enabled),
        )
        for row in module_rows
    ]

    return OrganizationDashboardSummaryResponse(
        organization_id=organization.id,
        organization_name=organization.name,
        organization_code=organization.code,
        active_station_count=active_station_count,
        inactive_station_count=inactive_station_count,
        completed_station_setup_count=completed_station_setup_count,
        pending_station_setup_count=pending_station_setup_count,
        active_forecourt_tank_count=active_forecourt_tank_count,
        active_forecourt_dispenser_count=active_forecourt_dispenser_count,
        active_forecourt_nozzle_count=active_forecourt_nozzle_count,
        open_shift_count=open_shift_count,
        active_staff_count=sum(1 for user in users if user.is_active),
        pending_customer_balance_total=round(pending_customer_balance_total, 2),
        pending_supplier_balance_total=round(pending_supplier_balance_total, 2),
        unread_notification_count=unread_notification_count,
        role_counts=role_counts,
        module_statuses=module_statuses,
    )


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
