from pydantic import BaseModel, ConfigDict
from datetime import datetime


class TankDipCreate(BaseModel):
    tank_id: int
    dip_reading_mm: float
    notes: str | None = None


class TankDipResponse(BaseModel):
    id: int
    tank_id: int
    dip_reading_mm: float
    calculated_volume: float
    system_volume: float
    loss_gain: float
    notes: str | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
