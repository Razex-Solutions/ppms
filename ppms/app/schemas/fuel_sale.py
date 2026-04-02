from pydantic import BaseModel, ConfigDict
from datetime import datetime


class FuelSaleCreate(BaseModel):
    nozzle_id: int
    station_id: int
    fuel_type_id: int
    customer_id: int | None = None
    closing_meter: float
    rate_per_liter: float
    sale_type: str = "cash"
    shift_name: str | None = None
    shift_id: int | None = None


class FuelSaleResponse(BaseModel):
    id: int
    nozzle_id: int
    station_id: int
    fuel_type_id: int
    customer_id: int | None = None
    opening_meter: float
    closing_meter: float
    quantity: float
    rate_per_liter: float
    total_amount: float
    sale_type: str
    shift_name: str | None = None
    shift_id: int | None = None
    is_reversed: bool
    reversed_at: datetime | None = None
    reversed_by: int | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
