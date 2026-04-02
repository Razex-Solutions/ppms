from pydantic import BaseModel
from datetime import datetime


class PurchaseCreate(BaseModel):
    supplier_id: int
    tank_id: int
    fuel_type_id: int
    tanker_id: int | None = None
    quantity: float
    rate_per_liter: float
    reference_no: str | None = None
    notes: str | None = None


class PurchaseResponse(BaseModel):
    id: int
    supplier_id: int
    tank_id: int
    fuel_type_id: int
    tanker_id: int | None = None
    quantity: float
    rate_per_liter: float
    total_amount: float
    reference_no: str | None = None
    notes: str | None = None
    is_reversed: bool
    reversed_at: datetime | None = None
    reversed_by: int | None = None
    created_at: datetime

    class Config:
        from_attributes = True
