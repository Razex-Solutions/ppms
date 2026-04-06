from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class InternalFuelUsageCreate(BaseModel):
    tank_id: int
    fuel_type_id: int
    quantity: float = Field(gt=0)
    purpose: str
    notes: str | None = None

    @field_validator("purpose")
    @classmethod
    def validate_purpose(cls, value: str) -> str:
        normalized = value.strip()
        if len(normalized) < 3:
            raise ValueError("Purpose must be at least 3 characters")
        return normalized


class InternalFuelUsageResponse(BaseModel):
    id: int
    station_id: int
    tank_id: int
    fuel_type_id: int
    quantity: float
    purpose: str
    notes: str | None = None
    used_by_user_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
