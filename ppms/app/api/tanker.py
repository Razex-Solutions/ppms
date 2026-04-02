from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.tanker import Tanker
from app.models.station import Station
from app.models.fuel_type import FuelType
from app.schemas.tanker import TankerCreate, TankerUpdate, TankerResponse

router = APIRouter(prefix="/tankers", tags=["Tankers"])


@router.post("/", response_model=TankerResponse)
def create_tanker(
    data: TankerCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    existing = db.query(Tanker).filter(Tanker.registration_no == data.registration_no).first()
    if existing:
        raise HTTPException(status_code=400, detail="Tanker registration already exists")

    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    fuel_type = db.query(FuelType).filter(FuelType.id == data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")

    tanker = Tanker(
        registration_no=data.registration_no,
        name=data.name,
        capacity=data.capacity,
        owner_name=data.owner_name,
        driver_name=data.driver_name,
        driver_phone=data.driver_phone,
        status=data.status,
        station_id=data.station_id,
        fuel_type_id=data.fuel_type_id
    )

    db.add(tanker)
    db.commit()
    db.refresh(tanker)
    return tanker


@router.get("/", response_model=list[TankerResponse])
def list_tankers(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    status: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(Tanker)
    if station_id:
        q = q.filter(Tanker.station_id == station_id)
    if status:
        q = q.filter(Tanker.status == status)
    return q.offset(skip).limit(limit).all()


@router.get("/{tanker_id}", response_model=TankerResponse)
def get_tanker(
    tanker_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != tanker.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")

    return tanker


@router.put("/{tanker_id}", response_model=TankerResponse)
def update_tanker(
    tanker_id: int, 
    data: TankerUpdate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != tanker.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(tanker, field, value)
    db.commit()
    db.refresh(tanker)
    return tanker


@router.delete("/{tanker_id}")
def delete_tanker(
    tanker_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != tanker.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")

    db.delete(tanker)
    db.commit()
    return {"message": "Tanker deleted"}