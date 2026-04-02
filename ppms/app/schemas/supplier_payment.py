from pydantic import BaseModel
from datetime import datetime


class SupplierPaymentCreate(BaseModel):
    supplier_id: int
    station_id: int
    amount: float
    payment_method: str = "cash"
    reference_no: str | None = None
    notes: str | None = None


class SupplierPaymentResponse(BaseModel):
    id: int
    supplier_id: int
    station_id: int
    amount: float
    payment_method: str
    reference_no: str | None = None
    notes: str | None = None
    is_reversed: bool
    reversed_at: datetime | None = None
    reversed_by: int | None = None
    created_at: datetime

    class Config:
        from_attributes = True
