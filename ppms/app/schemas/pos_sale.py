from datetime import datetime

from pydantic import BaseModel, ConfigDict


class POSSaleItemCreate(BaseModel):
    product_id: int
    quantity: float


class POSSaleCreate(BaseModel):
    station_id: int
    module: str
    payment_method: str = "cash"
    customer_name: str | None = None
    notes: str | None = None
    items: list[POSSaleItemCreate]


class POSSaleItemResponse(BaseModel):
    id: int
    product_id: int
    quantity: float
    unit_price: float
    line_total: float

    model_config = ConfigDict(from_attributes=True)


class POSSaleResponse(BaseModel):
    id: int
    station_id: int
    module: str
    payment_method: str
    customer_name: str | None = None
    notes: str | None = None
    total_amount: float
    is_reversed: bool
    reversed_at: datetime | None = None
    reversed_by: int | None = None
    created_at: datetime
    items: list[POSSaleItemResponse]

    model_config = ConfigDict(from_attributes=True)
