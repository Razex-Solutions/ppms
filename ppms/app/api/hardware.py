from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.hardware_device import HardwareDevice
from app.models.hardware_event import HardwareEvent
from app.models.user import User
from app.schemas.hardware import (
    HardwareDeviceCreate,
    HardwareDeviceResponse,
    HardwareDeviceUpdate,
    HardwareEventResponse,
    SimulatedDispenserReadingCreate,
    SimulatedTankProbeReadingCreate,
)
from app.services.hardware import (
    create_hardware_device,
    ensure_hardware_access,
    simulate_dispenser_reading,
    simulate_tank_probe_reading,
    update_hardware_device,
)

router = APIRouter(prefix="/hardware", tags=["Hardware"])


@router.post("/devices", response_model=HardwareDeviceResponse)
def create_device(
    data: HardwareDeviceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_hardware_device(db, data, current_user)


@router.get("/devices", response_model=list[HardwareDeviceResponse])
def list_devices(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    device_type: str | None = Query(None),
    status: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    query = db.query(HardwareDevice)
    if station_id is not None:
        query = query.filter(HardwareDevice.station_id == station_id)
    if device_type:
        query = query.filter(HardwareDevice.device_type == device_type)
    if status:
        query = query.filter(HardwareDevice.status == status)
    return query.offset(skip).limit(limit).all()


@router.get("/devices/{device_id}", response_model=HardwareDeviceResponse)
def get_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = db.query(HardwareDevice).filter(HardwareDevice.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Hardware device not found")
    ensure_hardware_access(device, current_user)
    return device


@router.put("/devices/{device_id}", response_model=HardwareDeviceResponse)
def update_device(
    device_id: int,
    data: HardwareDeviceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = db.query(HardwareDevice).filter(HardwareDevice.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Hardware device not found")
    return update_hardware_device(db, device, data, current_user)


@router.delete("/devices/{device_id}")
def delete_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = db.query(HardwareDevice).filter(HardwareDevice.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Hardware device not found")
    ensure_hardware_access(device, current_user)
    if db.query(HardwareEvent).filter(HardwareEvent.device_id == device.id).first():
        raise HTTPException(status_code=400, detail="Hardware device cannot be deleted while event history exists")
    db.delete(device)
    db.commit()
    return {"message": "Hardware device deleted"}


@router.get("/events", response_model=list[HardwareEventResponse])
def list_events(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    device_id: int | None = Query(None),
    event_type: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    query = db.query(HardwareEvent)
    if station_id is not None:
        query = query.filter(HardwareEvent.station_id == station_id)
    if device_id is not None:
        device = db.query(HardwareDevice).filter(HardwareDevice.id == device_id).first()
        if not device:
            raise HTTPException(status_code=404, detail="Hardware device not found")
        ensure_hardware_access(device, current_user)
        query = query.filter(HardwareEvent.device_id == device_id)
    if event_type:
        query = query.filter(HardwareEvent.event_type == event_type)
    return query.order_by(HardwareEvent.recorded_at.desc()).offset(skip).limit(limit).all()


@router.get("/events/{event_id}", response_model=HardwareEventResponse)
def get_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    event = db.query(HardwareEvent).filter(HardwareEvent.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Hardware event not found")
    require_station_access(current_user, event.station_id, detail="Not authorized for this hardware event")
    return event


@router.post("/simulate/dispenser-reading", response_model=HardwareEventResponse)
def ingest_dispenser_reading(
    data: SimulatedDispenserReadingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return simulate_dispenser_reading(db, data, current_user)


@router.post("/simulate/tank-probe-reading", response_model=HardwareEventResponse)
def ingest_tank_probe_reading(
    data: SimulatedTankProbeReadingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return simulate_tank_probe_reading(db, data, current_user)
