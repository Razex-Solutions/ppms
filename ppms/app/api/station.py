from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.customer import Customer
from app.models.dispenser import Dispenser
from app.models.expense import Expense
from app.models.organization import Organization
from app.models.station import Station
from app.models.tank import Tank
from app.models.tanker import Tanker
from app.models.user import User
from app.schemas.station import StationCreate, StationUpdate, StationResponse
from app.schemas.setup_foundation import StationSetupFoundationResponse
from app.services.setup_foundation import build_station_setup_foundation

router = APIRouter(prefix="/stations", tags=["Stations"])


def _apply_station_branding(
    *,
    station: Station,
    organization: Organization,
    use_organization_branding: bool | None = None,
) -> None:
    if use_organization_branding is None:
        use_organization_branding = station.use_organization_branding

    if use_organization_branding:
        station.brand_name = organization.brand_name
        station.brand_code = organization.brand_code
        station.logo_url = organization.logo_url


def _serialize_station(station: Station) -> dict[str, object | None]:
    organization = station.organization
    resolved_brand_name = station.brand_name
    resolved_brand_code = station.brand_code
    resolved_logo_url = station.logo_url
    if station.use_organization_branding and organization is not None:
        resolved_brand_name = organization.brand_name or resolved_brand_name
        resolved_brand_code = organization.brand_code or resolved_brand_code
        resolved_logo_url = organization.logo_url or resolved_logo_url

    return {
        "id": station.id,
        "name": station.name,
        "code": station.code,
        "address": station.address,
        "city": station.city,
        "organization_id": station.organization_id,
        "is_head_office": station.is_head_office,
        "display_name": station.display_name,
        "legal_name_override": station.legal_name_override,
        "brand_name": resolved_brand_name,
        "brand_code": resolved_brand_code,
        "logo_url": resolved_logo_url,
        "use_organization_branding": station.use_organization_branding,
        "is_active": station.is_active,
        "setup_status": station.setup_status,
        "setup_completed_at": station.setup_completed_at,
        "has_shops": station.has_shops,
        "has_pos": station.has_pos,
        "has_tankers": station.has_tankers,
        "has_hardware": station.has_hardware,
        "allow_meter_adjustments": station.allow_meter_adjustments,
        "created_at": station.created_at,
    }


@router.post("/", response_model=StationResponse)
def create_station(
    station_data: StationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_permission(current_user, "stations", "create", detail="You do not have permission to create stations")

    existing_station = db.query(Station).filter(Station.code == station_data.code).first()
    if existing_station:
        raise HTTPException(status_code=400, detail="Station code already exists")
    organization = db.query(Organization).filter(Organization.id == station_data.organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if not is_master_admin(current_user) and organization.id != get_user_organization_id(current_user):
        raise HTTPException(status_code=403, detail="Not authorized for this organization")
    if station_data.is_head_office:
        existing_head_office = db.query(Station).filter(
            Station.organization_id == station_data.organization_id,
            Station.is_head_office.is_(True),
        ).first()
        if existing_head_office:
            raise HTTPException(status_code=400, detail="Organization already has a head office station")

    payload = station_data.model_dump()
    station = Station(**payload)
    _apply_station_branding(
        station=station,
        organization=organization,
        use_organization_branding=station.use_organization_branding,
    )
    db.add(station)
    db.commit()
    db.refresh(station)
    return _serialize_station(station)


@router.get("/", response_model=list[StationResponse])
def list_stations(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    organization_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        query = db.query(Station)
        if organization_id is not None:
            query = query.filter(Station.organization_id == organization_id)
        return [_serialize_station(item) for item in query.offset(skip).limit(limit).all()]
    if is_head_office_user(current_user):
        require_permission(current_user, "stations", "read", detail="You do not have permission to view stations")
        user_organization_id = get_user_organization_id(current_user)
        query = db.query(Station).filter(Station.organization_id == user_organization_id)
        if organization_id is not None:
            if organization_id != user_organization_id:
                raise HTTPException(status_code=403, detail="Not authorized for this organization")
            query = query.filter(Station.organization_id == organization_id)
        return [_serialize_station(item) for item in query.offset(skip).limit(limit).all()]
    return [
        _serialize_station(item)
        for item in db.query(Station).filter(Station.id == current_user.station_id).offset(skip).limit(limit).all()
    ]


@router.get("/{station_id}", response_model=StationResponse)
def get_station(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return _serialize_station(station)
    if is_head_office_user(current_user):
        require_permission(current_user, "stations", "read", detail="You do not have permission to view stations")
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        return _serialize_station(station)
    if current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    return _serialize_station(station)


@router.get("/{station_id}/setup-foundation", response_model=StationSetupFoundationResponse)
def get_station_setup_foundation(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return build_station_setup_foundation(db, station)
    if is_head_office_user(current_user):
        require_permission(current_user, "stations", "read", detail="You do not have permission to view stations")
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        return build_station_setup_foundation(db, station)
    if current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    return build_station_setup_foundation(db, station)


@router.put("/{station_id}", response_model=StationResponse)
def update_station(
    station_id: int,
    data: StationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    require_permission(current_user, "stations", "update", detail="You do not have permission to update stations")
    if not is_master_admin(current_user) and station.organization_id != get_user_organization_id(current_user):
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    updates = data.model_dump(exclude_unset=True)
    new_organization_id = updates.get("organization_id", station.organization_id)
    if new_organization_id is not None:
        organization = db.query(Organization).filter(Organization.id == new_organization_id).first()
        if not organization:
            raise HTTPException(status_code=404, detail="Organization not found")
    else:
        organization = None
    new_is_head_office = updates.get("is_head_office", station.is_head_office)
    if new_is_head_office and new_organization_id is not None:
        existing_head_office = db.query(Station).filter(
            Station.organization_id == new_organization_id,
            Station.is_head_office.is_(True),
            Station.id != station.id,
        ).first()
        if existing_head_office:
            raise HTTPException(status_code=400, detail="Organization already has a head office station")
    for field, value in updates.items():
        setattr(station, field, value)
    if organization is not None:
        _apply_station_branding(
            station=station,
            organization=organization,
            use_organization_branding=updates.get("use_organization_branding"),
        )
    db.commit()
    db.refresh(station)
    return _serialize_station(station)


@router.delete("/{station_id}")
def delete_station(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    require_permission(current_user, "stations", "delete", detail="You do not have permission to delete stations")
    if not is_master_admin(current_user) and station.organization_id != get_user_organization_id(current_user):
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    if station.users:
        raise HTTPException(status_code=400, detail="Station cannot be deleted while users are assigned to it")
    has_tanks = db.query(Tank).filter(Tank.station_id == station.id).first()
    has_dispensers = db.query(Dispenser).filter(Dispenser.station_id == station.id).first()
    has_customers = db.query(Customer).filter(Customer.station_id == station.id).first()
    has_expenses = db.query(Expense).filter(Expense.station_id == station.id).first()
    has_tankers = db.query(Tanker).filter(Tanker.station_id == station.id).first()
    if has_tanks or has_dispensers or has_customers or has_expenses or has_tankers:
        raise HTTPException(status_code=400, detail="Station cannot be deleted while dependent records exist")
    db.delete(station)
    db.commit()
    return {"message": "Station deleted"}
