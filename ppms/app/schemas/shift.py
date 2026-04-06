from pydantic import BaseModel, ConfigDict
from datetime import datetime


class ShiftCreate(BaseModel):
    station_id: int
    shift_template_id: int | None = None
    initial_cash: float = 0.0
    notes: str | None = None


class ShiftUpdate(BaseModel):
    actual_cash_collected: float
    notes: str | None = None


class ShiftResponse(BaseModel):
    id: int
    station_id: int
    user_id: int
    shift_template_id: int | None = None
    shift_name: str | None = None
    start_time: datetime
    end_time: datetime | None = None
    status: str
    initial_cash: float
    total_sales_cash: float
    total_sales_credit: float
    expected_cash: float
    actual_cash_collected: float | None = None
    difference: float | None = None
    notes: str | None = None

    model_config = ConfigDict(from_attributes=True)
