from datetime import datetime

from pydantic import BaseModel, ConfigDict


class HardwareDeviceCreate(BaseModel):
    name: str
    code: str
    device_type: str
    integration_mode: str = "simulated"
    status: str = "offline"
    is_active: bool = True
    station_id: int
    dispenser_id: int | None = None
    tank_id: int | None = None


class HardwareDeviceUpdate(BaseModel):
    name: str | None = None
    integration_mode: str | None = None
    status: str | None = None
    is_active: bool | None = None
    dispenser_id: int | None = None
    tank_id: int | None = None
    last_error: str | None = None


class HardwareDeviceResponse(BaseModel):
    id: int
    name: str
    code: str
    device_type: str
    integration_mode: str
    status: str
    is_active: bool
    station_id: int
    dispenser_id: int | None = None
    tank_id: int | None = None
    last_seen_at: datetime | None = None
    last_error: str | None = None

    model_config = ConfigDict(from_attributes=True)


class HardwareEventResponse(BaseModel):
    id: int
    device_id: int
    station_id: int
    event_type: str
    source: str
    status: str
    dispenser_id: int | None = None
    tank_id: int | None = None
    nozzle_id: int | None = None
    meter_reading: float | None = None
    volume: float | None = None
    temperature: float | None = None
    notes: str | None = None
    payload_json: str | None = None
    recorded_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SimulatedDispenserReadingCreate(BaseModel):
    device_id: int
    nozzle_id: int
    meter_reading: float
    volume: float | None = None
    status: str = "received"
    notes: str | None = None


class SimulatedTankProbeReadingCreate(BaseModel):
    device_id: int
    volume: float
    temperature: float | None = None
    status: str = "received"
    notes: str | None = None
