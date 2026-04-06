from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator


class FuelPriceHistoryCreate(BaseModel):
    station_id: int
    price: float
    effective_at: datetime | None = None
    reason: str
    notes: str | None = None

    @field_validator("price")
    @classmethod
    def validate_price(cls, value: float) -> float:
        rounded = round(float(value), 2)
        if rounded <= 0:
            raise ValueError("Price must be greater than zero")
        return rounded

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Reason is required")
        return normalized


class FuelPriceHistoryResponse(BaseModel):
    id: int
    station_id: int
    fuel_type_id: int
    price: float
    effective_at: datetime
    reason: str
    notes: str | None = None
    created_by_user_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
