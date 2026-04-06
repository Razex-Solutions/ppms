from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_admin, require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.core.time import utc_now
from app.models.fuel_type import FuelType
from app.models.fuel_price_history import FuelPriceHistory
from app.models.nozzle import Nozzle
from app.models.purchase import Purchase
from app.models.station import Station
from app.models.tank import Tank
from app.models.user import User
from app.schemas.fuel_type import FuelTypeCreate, FuelTypeUpdate, FuelTypeResponse
from app.schemas.fuel_price_history import FuelPriceHistoryCreate, FuelPriceHistoryResponse

router = APIRouter(prefix="/fuel-types", tags=["Fuel Types"])


def _ensure_pricing_station_access(
    db: Session,
    *,
    station_id: int,
    current_user: User,
    write: bool = False,
) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return station
    if is_head_office_user(current_user):
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        require_permission(
            current_user,
            "fuel_pricing",
            "update" if write else "read",
            detail="You do not have permission to access fuel pricing",
        )
        return station
    require_station_access(current_user, station_id, detail="Not authorized for this station")
    require_permission(
        current_user,
        "fuel_pricing",
        "update" if write else "read",
        detail="You do not have permission to access fuel pricing",
    )
    return station


@router.post("/", response_model=FuelTypeResponse)
def create_fuel_type(
    fuel_data: FuelTypeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)
    existing = db.query(FuelType).filter(FuelType.name == fuel_data.name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Fuel type already exists")

    fuel_type = FuelType(
        name=fuel_data.name,
        description=fuel_data.description
    )
    db.add(fuel_type)
    db.commit()
    db.refresh(fuel_type)
    return fuel_type


@router.get("/", response_model=list[FuelTypeResponse])
def list_fuel_types(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(FuelType).offset(skip).limit(limit).all()


@router.get("/{fuel_type_id}", response_model=FuelTypeResponse)
def get_fuel_type(
    fuel_type_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ft = db.query(FuelType).filter(FuelType.id == fuel_type_id).first()
    if not ft:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    return ft


@router.put("/{fuel_type_id}", response_model=FuelTypeResponse)
def update_fuel_type(
    fuel_type_id: int,
    data: FuelTypeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)
    ft = db.query(FuelType).filter(FuelType.id == fuel_type_id).first()
    if not ft:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(ft, field, value)
    db.commit()
    db.refresh(ft)
    return ft


@router.delete("/{fuel_type_id}")
def delete_fuel_type(
    fuel_type_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_admin(current_user)
    ft = db.query(FuelType).filter(FuelType.id == fuel_type_id).first()
    if not ft:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    has_tanks = db.query(Tank).filter(Tank.fuel_type_id == ft.id).first()
    has_nozzles = db.query(Nozzle).filter(Nozzle.fuel_type_id == ft.id).first()
    has_purchases = db.query(Purchase).filter(Purchase.fuel_type_id == ft.id).first()
    if has_tanks or has_nozzles or has_purchases:
        raise HTTPException(status_code=400, detail="Fuel type cannot be deleted while dependent records exist")
    db.delete(ft)
    db.commit()
    return {"message": "Fuel type deleted"}


@router.get("/{fuel_type_id}/price-history", response_model=list[FuelPriceHistoryResponse])
def list_fuel_price_history(
    fuel_type_id: int,
    station_id: int = Query(...),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    fuel_type = db.query(FuelType).filter(FuelType.id == fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    _ensure_pricing_station_access(db, station_id=station_id, current_user=current_user)
    return (
        db.query(FuelPriceHistory)
        .filter(
            FuelPriceHistory.fuel_type_id == fuel_type_id,
            FuelPriceHistory.station_id == station_id,
        )
        .order_by(FuelPriceHistory.effective_at.desc(), FuelPriceHistory.id.desc())
        .limit(limit)
        .all()
    )


@router.post("/{fuel_type_id}/price-history", response_model=FuelPriceHistoryResponse)
def create_fuel_price_history(
    fuel_type_id: int,
    data: FuelPriceHistoryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    fuel_type = db.query(FuelType).filter(FuelType.id == fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    _ensure_pricing_station_access(db, station_id=data.station_id, current_user=current_user, write=True)
    entry = FuelPriceHistory(
        station_id=data.station_id,
        fuel_type_id=fuel_type_id,
        price=data.price,
        effective_at=data.effective_at or utc_now(),
        reason=data.reason,
        notes=data.notes,
        created_by_user_id=current_user.id,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry
