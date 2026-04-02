from pydantic import BaseModel
from datetime import datetime


class TankDipCreate(BaseModel):
    tank_id: int
    dip_reading_mm: float
    calculated_volume: float
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

    class Config:
        from_attributes = True
