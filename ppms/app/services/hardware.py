import json

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import require_station_access
from app.core.time import utc_now
from app.models.dispenser import Dispenser
from app.models.hardware_device import HardwareDevice
from app.models.hardware_event import HardwareEvent
from app.models.nozzle import Nozzle
from app.models.station import Station
from app.models.tank import Tank
from app.models.user import User
from app.schemas.hardware import (
    HardwareDeviceCreate,
    HardwareDeviceUpdate,
    SimulatedDispenserReadingCreate,
    SimulatedTankProbeReadingCreate,
)
from app.services.hardware_adapters import RECOGNIZED_VENDORS, get_hardware_adapter
from app.services.audit import log_audit_event


VALID_DEVICE_TYPES = {"dispenser", "tank_probe", "printer", "other"}
VALID_INTEGRATION_MODES = {"manual", "simulated", "vendor_api"}
VALID_DEVICE_STATUSES = {"online", "offline", "error", "maintenance"}
VALID_EVENT_STATUSES = {"received", "warning", "error"}
VALID_PROTOCOLS = {"http", "https", "tcp", "udp"}


def ensure_hardware_access(device: HardwareDevice, current_user: User) -> None:
    require_station_access(current_user, device.station_id, detail="Not authorized for this hardware device")


def _validate_station(db: Session, station_id: int) -> None:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")


def _validate_linked_assets(
    db: Session,
    station_id: int,
    device_type: str,
    dispenser_id: int | None,
    tank_id: int | None,
) -> None:
    if dispenser_id is not None:
        dispenser = db.query(Dispenser).filter(Dispenser.id == dispenser_id).first()
        if not dispenser:
            raise HTTPException(status_code=404, detail="Dispenser not found")
        if dispenser.station_id != station_id:
            raise HTTPException(status_code=400, detail="Dispenser does not belong to the selected station")

    if tank_id is not None:
        tank = db.query(Tank).filter(Tank.id == tank_id).first()
        if not tank:
            raise HTTPException(status_code=404, detail="Tank not found")
        if tank.station_id != station_id:
            raise HTTPException(status_code=400, detail="Tank does not belong to the selected station")

    if device_type == "dispenser" and dispenser_id is None:
        raise HTTPException(status_code=400, detail="Dispenser hardware must be linked to a dispenser")
    if device_type == "tank_probe" and tank_id is None:
        raise HTTPException(status_code=400, detail="Tank probe hardware must be linked to a tank")
    if device_type == "dispenser" and tank_id is not None:
        raise HTTPException(status_code=400, detail="Dispenser hardware cannot be linked directly to a tank")
    if device_type == "tank_probe" and dispenser_id is not None:
        raise HTTPException(status_code=400, detail="Tank probe hardware cannot be linked directly to a dispenser")


def _validate_device_payload(
    db: Session,
    station_id: int,
    device_type: str,
    integration_mode: str,
    status: str,
    dispenser_id: int | None,
    tank_id: int | None,
) -> None:
    if device_type not in VALID_DEVICE_TYPES:
        raise HTTPException(status_code=400, detail="Invalid hardware device type")
    if integration_mode not in VALID_INTEGRATION_MODES:
        raise HTTPException(status_code=400, detail="Invalid hardware integration mode")
    if status not in VALID_DEVICE_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid hardware status")

    _validate_station(db, station_id)
    _validate_linked_assets(db, station_id, device_type, dispenser_id, tank_id)


def _validate_vendor_configuration(device: HardwareDevice | HardwareDeviceCreate | HardwareDeviceUpdate, device_type: str, integration_mode: str) -> None:
    vendor_name = (getattr(device, "vendor_name", None) or "").strip().lower()
    protocol = getattr(device, "protocol", None)
    endpoint_url = getattr(device, "endpoint_url", None)
    device_identifier = getattr(device, "device_identifier", None)

    if integration_mode != "vendor_api":
        return
    if not vendor_name:
        raise HTTPException(status_code=400, detail="Vendor name is required for vendor API hardware")
    if protocol and protocol not in VALID_PROTOCOLS:
        raise HTTPException(status_code=400, detail="Invalid hardware protocol")
    if not device_identifier:
        raise HTTPException(status_code=400, detail="Device identifier is required for vendor API hardware")
    if device_type not in {"dispenser", "tank_probe"}:
        raise HTTPException(status_code=400, detail="Vendor API integration currently supports dispenser and tank probe devices only")
    if vendor_name in {"veederroot", "opw"} and device_type != "tank_probe":
        raise HTTPException(status_code=400, detail=f"{vendor_name} adapter currently supports tank probes only")
    if vendor_name in {"tokheim", "gilbarco"} and device_type != "dispenser":
        raise HTTPException(status_code=400, detail=f"{vendor_name} adapter currently supports dispenser devices only")
    if endpoint_url and not endpoint_url.startswith(("http://", "https://")):
        raise HTTPException(status_code=400, detail="Hardware endpoint URL must start with http:// or https://")


def create_hardware_device(db: Session, data: HardwareDeviceCreate, current_user: User) -> HardwareDevice:
    require_station_access(current_user, data.station_id)
    existing = db.query(HardwareDevice).filter(HardwareDevice.code == data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Hardware device code already exists")

    _validate_device_payload(
        db,
        station_id=data.station_id,
        device_type=data.device_type,
        integration_mode=data.integration_mode,
        status=data.status,
        dispenser_id=data.dispenser_id,
        tank_id=data.tank_id,
    )
    _validate_vendor_configuration(data, data.device_type, data.integration_mode)

    device = HardwareDevice(**data.model_dump())
    db.add(device)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="hardware",
        action="hardware.create",
        entity_type="hardware_device",
        entity_id=device.id,
        station_id=device.station_id,
        details={"device_type": device.device_type, "code": device.code},
    )
    db.commit()
    db.refresh(device)
    return device


def update_hardware_device(
    db: Session,
    device: HardwareDevice,
    data: HardwareDeviceUpdate,
    current_user: User,
) -> HardwareDevice:
    ensure_hardware_access(device, current_user)
    updates = data.model_dump(exclude_unset=True)

    integration_mode = updates.get("integration_mode", device.integration_mode)
    status = updates.get("status", device.status)
    dispenser_id = updates.get("dispenser_id", device.dispenser_id)
    tank_id = updates.get("tank_id", device.tank_id)

    _validate_device_payload(
        db,
        station_id=device.station_id,
        device_type=device.device_type,
        integration_mode=integration_mode,
        status=status,
        dispenser_id=dispenser_id,
        tank_id=tank_id,
    )
    merged = HardwareDevice(
        vendor_name=updates.get("vendor_name", device.vendor_name),
        protocol=updates.get("protocol", device.protocol),
        endpoint_url=updates.get("endpoint_url", device.endpoint_url),
        device_identifier=updates.get("device_identifier", device.device_identifier),
        api_key=updates.get("api_key", device.api_key),
    )
    _validate_vendor_configuration(merged, device.device_type, integration_mode)

    for field, value in updates.items():
        setattr(device, field, value)

    log_audit_event(
        db,
        current_user=current_user,
        module="hardware",
        action="hardware.update",
        entity_type="hardware_device",
        entity_id=device.id,
        station_id=device.station_id,
        details=updates,
    )
    db.commit()
    db.refresh(device)
    return device


def _validate_event_status(status: str) -> None:
    if status not in VALID_EVENT_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid hardware event status")


def _record_event(
    db: Session,
    device: HardwareDevice,
    event_type: str,
    status: str,
    payload: dict,
    dispenser_id: int | None = None,
    tank_id: int | None = None,
    nozzle_id: int | None = None,
    meter_reading: float | None = None,
    volume: float | None = None,
    temperature: float | None = None,
    notes: str | None = None,
) -> HardwareEvent:
    event = HardwareEvent(
        device_id=device.id,
        station_id=device.station_id,
        event_type=event_type,
        source="simulation",
        status=status,
        dispenser_id=dispenser_id,
        tank_id=tank_id,
        nozzle_id=nozzle_id,
        meter_reading=meter_reading,
        volume=volume,
        temperature=temperature,
        notes=notes,
        payload_json=json.dumps(payload, sort_keys=True),
    )
    device.status = "online"
    device.last_seen_at = utc_now()
    if status != "error":
        device.last_error = None
    elif notes:
        device.last_error = notes

    db.add(event)
    db.flush()
    log_audit_event(
        db,
        current_user=None,
        module="hardware",
        action=f"hardware.{event_type}",
        entity_type="hardware_event",
        entity_id=event.id,
        station_id=device.station_id,
        details=payload,
    )
    db.commit()
    db.refresh(event)
    return event


def simulate_dispenser_reading(
    db: Session,
    data: SimulatedDispenserReadingCreate,
    current_user: User,
) -> HardwareEvent:
    _validate_event_status(data.status)
    if data.meter_reading < 0:
        raise HTTPException(status_code=400, detail="Meter reading cannot be negative")
    if data.volume is not None and data.volume < 0:
        raise HTTPException(status_code=400, detail="Volume cannot be negative")

    device = db.query(HardwareDevice).filter(HardwareDevice.id == data.device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Hardware device not found")
    ensure_hardware_access(device, current_user)
    if not device.is_active:
        raise HTTPException(status_code=400, detail="Inactive hardware device cannot receive readings")
    if device.device_type != "dispenser":
        raise HTTPException(status_code=400, detail="Selected hardware device is not a dispenser device")
    get_hardware_adapter(device).ensure_supported(device)
    if device.dispenser_id is None:
        raise HTTPException(status_code=400, detail="Dispenser hardware is not linked to a dispenser")

    nozzle = db.query(Nozzle).filter(Nozzle.id == data.nozzle_id).first()
    if not nozzle:
        raise HTTPException(status_code=404, detail="Nozzle not found")
    if nozzle.dispenser_id != device.dispenser_id:
        raise HTTPException(status_code=400, detail="Nozzle does not belong to the linked dispenser")

    dispenser = db.query(Dispenser).filter(Dispenser.id == device.dispenser_id).first()
    if not dispenser or dispenser.station_id != device.station_id:
        raise HTTPException(status_code=400, detail="Linked dispenser is invalid for this station")

    return _record_event(
        db,
        device=device,
        event_type="dispenser_reading",
        status=data.status,
        dispenser_id=device.dispenser_id,
        nozzle_id=nozzle.id,
        meter_reading=data.meter_reading,
        volume=data.volume,
        notes=data.notes,
        payload={
            "device_id": device.id,
            "dispenser_id": device.dispenser_id,
            "nozzle_id": nozzle.id,
            "meter_reading": data.meter_reading,
            "volume": data.volume,
            "status": data.status,
            "notes": data.notes,
        },
    )


def simulate_tank_probe_reading(
    db: Session,
    data: SimulatedTankProbeReadingCreate,
    current_user: User,
) -> HardwareEvent:
    _validate_event_status(data.status)
    if data.volume < 0:
        raise HTTPException(status_code=400, detail="Volume cannot be negative")

    device = db.query(HardwareDevice).filter(HardwareDevice.id == data.device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Hardware device not found")
    ensure_hardware_access(device, current_user)
    if not device.is_active:
        raise HTTPException(status_code=400, detail="Inactive hardware device cannot receive readings")
    if device.device_type != "tank_probe":
        raise HTTPException(status_code=400, detail="Selected hardware device is not a tank probe")
    get_hardware_adapter(device).ensure_supported(device)
    if device.tank_id is None:
        raise HTTPException(status_code=400, detail="Tank probe hardware is not linked to a tank")

    tank = db.query(Tank).filter(Tank.id == device.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    if tank.station_id != device.station_id:
        raise HTTPException(status_code=400, detail="Linked tank is invalid for this station")

    return _record_event(
        db,
        device=device,
        event_type="tank_probe_reading",
        status=data.status,
        tank_id=device.tank_id,
        volume=data.volume,
        temperature=data.temperature,
        notes=data.notes,
        payload={
            "device_id": device.id,
            "tank_id": device.tank_id,
            "volume": data.volume,
            "temperature": data.temperature,
            "status": data.status,
            "notes": data.notes,
        },
    )


def check_hardware_adapter(device: HardwareDevice, current_user: User) -> dict:
    ensure_hardware_access(device, current_user)
    return get_hardware_adapter(device).health_check(device)


def get_supported_hardware_vendors() -> dict:
    return {
        "recognized_vendors": sorted(RECOGNIZED_VENDORS),
        "device_support": {
            "veederroot": ["tank_probe"],
            "opw": ["tank_probe"],
            "tokheim": ["dispenser"],
            "gilbarco": ["dispenser"],
            "generic": ["dispenser", "tank_probe"],
        },
        "protocols": sorted(VALID_PROTOCOLS),
    }


def poll_vendor_hardware_device(
    db: Session,
    *,
    device: HardwareDevice,
    current_user: User,
) -> HardwareEvent:
    ensure_hardware_access(device, current_user)
    if not device.is_active:
        raise HTTPException(status_code=400, detail="Inactive hardware device cannot be polled")
    adapter = get_hardware_adapter(device)
    snapshot = adapter.fetch_snapshot(device)
    status = snapshot.get("status", "received")
    _validate_event_status(status)

    if device.device_type == "dispenser":
        meter_reading = snapshot.get("meter_reading")
        volume = snapshot.get("volume")
        if meter_reading is None:
            raise HTTPException(status_code=400, detail="Vendor dispenser snapshot is missing meter_reading")
        return _record_event(
            db,
            device=device,
            event_type="vendor_dispenser_poll",
            status=status,
            dispenser_id=device.dispenser_id,
            nozzle_id=None,
            meter_reading=float(meter_reading),
            volume=float(volume) if volume is not None else None,
            notes=snapshot.get("notes"),
            payload=snapshot,
        )

    if device.device_type == "tank_probe":
        volume = snapshot.get("tank_volume", snapshot.get("volume"))
        if volume is None:
            raise HTTPException(status_code=400, detail="Vendor tank probe snapshot is missing volume")
        return _record_event(
            db,
            device=device,
            event_type="vendor_tank_probe_poll",
            status=status,
            tank_id=device.tank_id,
            volume=float(volume),
            temperature=float(snapshot["temperature"]) if snapshot.get("temperature") is not None else None,
            notes=snapshot.get("notes"),
            payload=snapshot,
        )

    raise HTTPException(status_code=400, detail="Vendor polling is not supported for this hardware device type")
