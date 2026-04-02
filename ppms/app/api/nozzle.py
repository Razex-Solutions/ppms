from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.nozzle import Nozzle
from app.models.dispenser import Dispenser
from app.models.tank import Tank
from app.models.fuel_type import FuelType
from app.models.meter_adjustment_event import MeterAdjustmentEvent
from app.models.nozzle_reading import NozzleReading
from app.schemas.nozzle import NozzleCreate, NozzleUpdate, NozzleResponse
from app.schemas.meter_adjustment_event import MeterAdjustmentEventResponse, MeterAdjustmentRequest
from app.schemas.nozzle_reading import NozzleReadingResponse
from app.services.nozzle_meter import adjust_nozzle_meter

router = APIRouter(prefix="/nozzles", tags=["Nozzles"])


@router.post("/", response_model=NozzleResponse)
def create_nozzle(
    nozzle_data: NozzleCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    require_permission(current_user, "nozzles", "create", detail="You do not have permission to create nozzles")
    dispenser = db.query(Dispenser).filter(Dispenser.id == nozzle_data.dispenser_id).first()
    if not dispenser:
        raise HTTPException(status_code=404, detail="Dispenser not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    existing = db.query(Nozzle).filter(Nozzle.code == nozzle_data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Nozzle code already exists")

    dispenser = db.query(Dispenser).filter(Dispenser.id == nozzle_data.dispenser_id).first()
    if not dispenser:
        raise HTTPException(status_code=404, detail="Dispenser not found")

    tank = db.query(Tank).filter(Tank.id == nozzle_data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")

    fuel_type = db.query(FuelType).filter(FuelType.id == nozzle_data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")

    nozzle = Nozzle(
        name=nozzle_data.name,
        code=nozzle_data.code,
        meter_reading=nozzle_data.meter_reading,
        current_segment_start_reading=nozzle_data.meter_reading,
        dispenser_id=nozzle_data.dispenser_id,
        tank_id=nozzle_data.tank_id,
        fuel_type_id=nozzle_data.fuel_type_id
    )
    db.add(nozzle)
    db.commit()
    db.refresh(nozzle)
    return nozzle


@router.get("/", response_model=list[NozzleResponse])
def list_nozzles(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    dispenser_id: int | None = Query(None),
    fuel_type_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(Nozzle)
    if station_id:
        q = q.join(Dispenser).filter(Dispenser.station_id == station_id)
    if dispenser_id:
        q = q.filter(Nozzle.dispenser_id == dispenser_id)
    if fuel_type_id:
        q = q.filter(Nozzle.fuel_type_id == fuel_type_id)
    return q.offset(skip).limit(limit).all()


@router.get("/{nozzle_id}", response_model=NozzleResponse)
def get_nozzle(
    nozzle_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    nozzle = db.query(Nozzle).filter(Nozzle.id == nozzle_id).first()
    if not nozzle:
        raise HTTPException(status_code=404, detail="Nozzle not found")

    require_permission(current_user, "nozzles", "update", detail="You do not have permission to update nozzles")
    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != nozzle.dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this nozzle")

    return nozzle


@router.put("/{nozzle_id}", response_model=NozzleResponse)
def update_nozzle(
    nozzle_id: int, 
    data: NozzleUpdate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    nozzle = db.query(Nozzle).filter(Nozzle.id == nozzle_id).first()
    if not nozzle:
        raise HTTPException(status_code=404, detail="Nozzle not found")

    require_permission(current_user, "nozzles", "delete", detail="You do not have permission to delete nozzles")
    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != nozzle.dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this nozzle")

    changes = data.model_dump(exclude_unset=True)
    if "meter_reading" in changes:
        raise HTTPException(status_code=400, detail="Use the dedicated meter adjustment endpoint to change nozzle meter readings")
    for field, value in changes.items():
        setattr(nozzle, field, value)
    db.commit()
    db.refresh(nozzle)
    return nozzle


@router.delete("/{nozzle_id}")
def delete_nozzle(
    nozzle_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    nozzle = db.query(Nozzle).filter(Nozzle.id == nozzle_id).first()
    if not nozzle:
        raise HTTPException(status_code=404, detail="Nozzle not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != nozzle.dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this nozzle")

    db.delete(nozzle)
    db.commit()
    return {"message": "Nozzle deleted"}


@router.get("/{nozzle_id}/readings", response_model=list[NozzleReadingResponse])
def get_nozzle_readings(
    nozzle_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    nozzle = db.query(Nozzle).filter(Nozzle.id == nozzle_id).first()
    if not nozzle:
        raise HTTPException(status_code=404, detail="Nozzle not found")

    require_permission(current_user, "nozzles", "read_meter_history", detail="You do not have permission to view nozzle meter history")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != nozzle.dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this nozzle")

    return db.query(NozzleReading).filter(
        NozzleReading.nozzle_id == nozzle_id
    ).order_by(NozzleReading.created_at.desc()).offset(skip).limit(limit).all()


@router.post("/{nozzle_id}/adjust-meter", response_model=MeterAdjustmentEventResponse)
def adjust_meter_reading(
    nozzle_id: int,
    data: MeterAdjustmentRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    require_permission(current_user, "nozzles", "adjust_meter", detail="You do not have permission to adjust nozzle meter readings")
    nozzle = db.query(Nozzle).filter(Nozzle.id == nozzle_id).first()
    if not nozzle:
        raise HTTPException(status_code=404, detail="Nozzle not found")

    if current_user.role.name != "Admin" and current_user.station_id != nozzle.dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this nozzle")

    return adjust_nozzle_meter(
        db,
        nozzle=nozzle,
        new_reading=data.new_reading,
        reason=data.reason,
        current_user=current_user,
    )


@router.get("/{nozzle_id}/adjustments", response_model=list[MeterAdjustmentEventResponse])
def get_meter_adjustments(
    nozzle_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    require_permission(current_user, "nozzles", "read_meter_history", detail="You do not have permission to view nozzle meter history")
    nozzle = db.query(Nozzle).filter(Nozzle.id == nozzle_id).first()
    if not nozzle:
        raise HTTPException(status_code=404, detail="Nozzle not found")

    if current_user.role.name != "Admin" and current_user.station_id != nozzle.dispenser.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this nozzle")

    return db.query(MeterAdjustmentEvent).filter(
        MeterAdjustmentEvent.nozzle_id == nozzle_id
    ).order_by(MeterAdjustmentEvent.adjusted_at.desc()).offset(skip).limit(limit).all()
