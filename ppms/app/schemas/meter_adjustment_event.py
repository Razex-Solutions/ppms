from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class MeterAdjustmentRequest(BaseModel):
    new_reading: float = Field(..., ge=0)
    reason: str = Field(..., min_length=3, max_length=255)


class MeterAdjustmentEventResponse(BaseModel):
    id: int
    nozzle_id: int
    station_id: int
    old_reading: float
    new_reading: float
    reason: str
    adjusted_by_user_id: int
    adjusted_at: datetime

    model_config = ConfigDict(from_attributes=True)
