from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_admin
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

router = APIRouter(prefix="/stations", tags=["Stations"])


@router.post("/", response_model=StationResponse)
def create_station(
    station_data: StationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)

    existing_station = db.query(Station).filter(Station.code == station_data.code).first()
    if existing_station:
        raise HTTPException(status_code=400, detail="Station code already exists")
    organization = db.query(Organization).filter(Organization.id == station_data.organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if station_data.is_head_office:
        existing_head_office = db.query(Station).filter(
            Station.organization_id == station_data.organization_id,
            Station.is_head_office.is_(True),
        ).first()
        if existing_head_office:
            raise HTTPException(status_code=400, detail="Organization already has a head office station")

    station = Station(
        **station_data.model_dump()
    )
    db.add(station)
    db.commit()
    db.refresh(station)
    return station


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
        return query.offset(skip).limit(limit).all()
    if is_head_office_user(current_user):
        require_permission(current_user, "stations", "read", detail="You do not have permission to view stations")
        user_organization_id = get_user_organization_id(current_user)
        query = db.query(Station).filter(Station.organization_id == user_organization_id)
        if organization_id is not None:
            if organization_id != user_organization_id:
                raise HTTPException(status_code=403, detail="Not authorized for this organization")
            query = query.filter(Station.organization_id == organization_id)
        return query.offset(skip).limit(limit).all()
    return db.query(Station).filter(Station.id == current_user.station_id).offset(skip).limit(limit).all()


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
        return station
    if is_head_office_user(current_user):
        require_permission(current_user, "stations", "read", detail="You do not have permission to view stations")
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        return station
    if current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    return station


@router.put("/{station_id}", response_model=StationResponse)
def update_station(
    station_id: int,
    data: StationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    updates = data.model_dump(exclude_unset=True)
    new_organization_id = updates.get("organization_id", station.organization_id)
    if new_organization_id is not None:
        organization = db.query(Organization).filter(Organization.id == new_organization_id).first()
        if not organization:
            raise HTTPException(status_code=404, detail="Organization not found")
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
    db.commit()
    db.refresh(station)
    return station


@router.delete("/{station_id}")
def delete_station(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
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
