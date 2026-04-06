from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import is_master_admin, require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.tank import Tank
from app.models.station import Station
from app.models.fuel_type import FuelType
from app.models.nozzle import Nozzle
from app.models.purchase import Purchase
from app.models.tank_dip import TankDip
from app.models.user import User
from app.schemas.tank import TankCreate, TankUpdate, TankResponse

router = APIRouter(prefix="/tanks", tags=["Tanks"])


def _next_tank_index(db: Session, station_id: int) -> int:
    return db.query(Tank).filter(Tank.station_id == station_id).count() + 1


@router.post("/", response_model=TankResponse)
def create_tank(
    tank_data: TankCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_permission(current_user, "tanks", "create", detail="You do not have permission to create tanks")
    require_station_access(current_user, tank_data.station_id)

    station = db.query(Station).filter(Station.id == tank_data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    fuel_type = db.query(FuelType).filter(FuelType.id == tank_data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")

    tank_index = _next_tank_index(db, tank_data.station_id)
    generated_name = tank_data.name or f"Tank {tank_index}"
    generated_code = tank_data.code or f"{station.code}-T{tank_index}"
    existing = db.query(Tank).filter(Tank.code == generated_code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Tank code already exists")

    tank = Tank(
        name=generated_name,
        code=generated_code,
        capacity=tank_data.capacity,
        current_volume=tank_data.current_volume,
        low_stock_threshold=tank_data.low_stock_threshold,
        location=tank_data.location,
        station_id=tank_data.station_id,
        fuel_type_id=tank_data.fuel_type_id
    )
    db.add(tank)
    db.commit()
    db.refresh(tank)
    return tank


@router.get("/", response_model=list[TankResponse])
def list_tanks(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    fuel_type_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    q = db.query(Tank)
    
    if current_user.role.name != "Admin" and not is_master_admin(current_user):
        station_id = current_user.station_id
        
    if station_id:
        q = q.filter(Tank.station_id == station_id)
    if fuel_type_id:
        q = q.filter(Tank.fuel_type_id == fuel_type_id)
    return q.offset(skip).limit(limit).all()


@router.get("/{tank_id}", response_model=TankResponse)
def get_tank(
    tank_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tank = db.query(Tank).filter(Tank.id == tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    require_station_access(current_user, tank.station_id, detail="Not authorized for this tank")
    return tank


@router.put("/{tank_id}", response_model=TankResponse)
def update_tank(
    tank_id: int,
    data: TankUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tank = db.query(Tank).filter(Tank.id == tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    require_station_access(current_user, tank.station_id, detail="Not authorized for this tank")
    require_permission(current_user, "tanks", "update", detail="You do not have permission to update tanks")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(tank, field, value)
    db.commit()
    db.refresh(tank)
    return tank


@router.delete("/{tank_id}")
def delete_tank(
    tank_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tank = db.query(Tank).filter(Tank.id == tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    require_station_access(current_user, tank.station_id, detail="Not authorized for this tank")
    require_permission(current_user, "tanks", "delete", detail="You do not have permission to delete tanks")
    has_nozzles = db.query(Nozzle).filter(Nozzle.tank_id == tank.id).first()
    has_purchases = db.query(Purchase).filter(Purchase.tank_id == tank.id).first()
    has_dips = db.query(TankDip).filter(TankDip.tank_id == tank.id).first()
    if has_nozzles or has_purchases or has_dips:
        raise HTTPException(status_code=400, detail="Tank cannot be deleted while dependent records exist")
    db.delete(tank)
    db.commit()
    return {"message": "Tank deleted"}
