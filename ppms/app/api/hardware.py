from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.hardware_device import HardwareDevice
from app.models.hardware_event import HardwareEvent
from app.models.station import Station
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
    check_hardware_adapter,
    create_hardware_device,
    ensure_hardware_access,
    get_supported_hardware_vendors,
    poll_vendor_hardware_device,
    simulate_dispenser_reading,
    simulate_tank_probe_reading,
    update_hardware_device,
)

router = APIRouter(prefix="/hardware", tags=["Hardware"])


@router.get("/vendors")
def list_hardware_vendors(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "hardware", "read", detail="You do not have permission to inspect hardware devices")
    return get_supported_hardware_vendors()


@router.post("/devices", response_model=HardwareDeviceResponse)
def create_device(
    data: HardwareDeviceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "hardware", "create", detail="You do not have permission to create hardware devices")
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
    query = db.query(HardwareDevice)
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        pass
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        query = query.join(Station, Station.id == HardwareDevice.station_id).filter(Station.organization_id == organization_id)
    else:
        station_id = current_user.station_id

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


@router.post("/devices/{device_id}/adapter-check")
def run_device_adapter_check(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = db.query(HardwareDevice).filter(HardwareDevice.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Hardware device not found")
    require_permission(current_user, "hardware", "read", detail="You do not have permission to inspect hardware devices")
    return check_hardware_adapter(device, current_user)


@router.post("/devices/{device_id}/vendor-poll", response_model=HardwareEventResponse)
def poll_vendor_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device = db.query(HardwareDevice).filter(HardwareDevice.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Hardware device not found")
    require_permission(current_user, "hardware", "read", detail="You do not have permission to inspect hardware devices")
    return poll_vendor_hardware_device(db, device=device, current_user=current_user)


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
    require_permission(current_user, "hardware", "update", detail="You do not have permission to update hardware devices")
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
    require_permission(current_user, "hardware", "delete", detail="You do not have permission to delete hardware devices")
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
    query = db.query(HardwareEvent)
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        pass
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        query = query.join(Station, Station.id == HardwareEvent.station_id).filter(Station.organization_id == organization_id)
    else:
        station_id = current_user.station_id

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
