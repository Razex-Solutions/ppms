from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.internal_fuel_usage import InternalFuelUsage
from app.models.station import Station
from app.models.user import User
from app.schemas.internal_fuel_usage import InternalFuelUsageCreate, InternalFuelUsageResponse
from app.services.internal_fuel_usage import create_internal_fuel_usage as create_internal_fuel_usage_service
from app.services.internal_fuel_usage import ensure_internal_fuel_usage_access

router = APIRouter(prefix="/internal-fuel-usage", tags=["Internal Fuel Usage"])


@router.post("/", response_model=InternalFuelUsageResponse)
def create_internal_fuel_usage(
    data: InternalFuelUsageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "internal_fuel_usage", "create", detail="You do not have permission to record internal fuel usage")
    return create_internal_fuel_usage_service(db, data, current_user)


@router.get("/", response_model=list[InternalFuelUsageResponse])
def list_internal_fuel_usage(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    tank_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "internal_fuel_usage", "read", detail="You do not have permission to view internal fuel usage")
    query = db.query(InternalFuelUsage)
    if is_master_admin(current_user):
        if station_id is not None:
            query = query.filter(InternalFuelUsage.station_id == station_id)
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        query = query.join(Station, Station.id == InternalFuelUsage.station_id).filter(Station.organization_id == organization_id)
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Not authorized for this station")
            query = query.filter(InternalFuelUsage.station_id == station_id)
    else:
        query = query.filter(InternalFuelUsage.station_id == current_user.station_id)

    if tank_id is not None:
        query = query.filter(InternalFuelUsage.tank_id == tank_id)
    return query.order_by(InternalFuelUsage.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{record_id}", response_model=InternalFuelUsageResponse)
def get_internal_fuel_usage(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "internal_fuel_usage", "read", detail="You do not have permission to view internal fuel usage")
    record = db.query(InternalFuelUsage).filter(InternalFuelUsage.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Internal fuel usage record not found")
    ensure_internal_fuel_usage_access(record, current_user)
    return record
