from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.dispenser import Dispenser
from app.models.station import Station
from app.schemas.dispenser import DispenserCreate, DispenserUpdate, DispenserResponse

router = APIRouter(prefix="/dispensers", tags=["Dispensers"])


@router.post("/", response_model=DispenserResponse)
def create_dispenser(
    dispenser_data: DispenserCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != dispenser_data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    existing = db.query(Dispenser).filter(Dispenser.code == dispenser_data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Dispenser code already exists")

    station = db.query(Station).filter(Station.id == dispenser_data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    dispenser = Dispenser(
        name=dispenser_data.name,
        code=dispenser_data.code,
        location=dispenser_data.location,
        station_id=dispenser_data.station_id
    )
    db.add(dispenser)
    db.commit()
    db.refresh(dispenser)
    return dispenser


@router.get("/", response_model=list[DispenserResponse])
def list_dispensers(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(Dispenser)
    if station_id:
        q = q.filter(Dispenser.station_id == station_id)
    return q.offset(skip).limit(limit).all()


@router.get("/{dispenser_id}", response_model=DispenserResponse)
def get_dispenser(
    dispenser_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    dispenser = db.query(Dispenser).filter(Dispenser.id == dispenser_id).first()
    if not dispenser:
        raise HTTPException(status_code=404, detail="Dispenser not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this dispenser")

    return dispenser


@router.put("/{dispenser_id}", response_model=DispenserResponse)
def update_dispenser(
    dispenser_id: int, 
    data: DispenserUpdate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    dispenser = db.query(Dispenser).filter(Dispenser.id == dispenser_id).first()
    if not dispenser:
        raise HTTPException(status_code=404, detail="Dispenser not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this dispenser")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(dispenser, field, value)
    db.commit()
    db.refresh(dispenser)
    return dispenser


@router.delete("/{dispenser_id}")
def delete_dispenser(
    dispenser_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    dispenser = db.query(Dispenser).filter(Dispenser.id == dispenser_id).first()
    if not dispenser:
        raise HTTPException(status_code=404, detail="Dispenser not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this dispenser")

    db.delete(dispenser)
    db.commit()
    return {"message": "Dispenser deleted"}