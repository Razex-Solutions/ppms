from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import require_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.customer import Customer
from app.models.dispenser import Dispenser
from app.models.expense import Expense
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

    station = Station(
        name=station_data.name,
        code=station_data.code,
        address=station_data.address,
        city=station_data.city
    )
    db.add(station)
    db.commit()
    db.refresh(station)
    return station


@router.get("/", response_model=list[StationResponse])
def list_stations(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role.name != "Admin":
        return db.query(Station).filter(Station.id == current_user.station_id).offset(skip).limit(limit).all()
    return db.query(Station).offset(skip).limit(limit).all()


@router.get("/{station_id}", response_model=StationResponse)
def get_station(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if current_user.role.name != "Admin" and current_user.station_id != station_id:
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
    for field, value in data.model_dump(exclude_unset=True).items():
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
