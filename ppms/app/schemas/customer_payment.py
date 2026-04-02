from pydantic import BaseModel, ConfigDict
from datetime import datetime


class CustomerPaymentCreate(BaseModel):
    customer_id: int
    station_id: int
    amount: float
    payment_method: str = "cash"
    reference_no: str | None = None
    notes: str | None = None


class CustomerPaymentResponse(BaseModel):
    id: int
    customer_id: int
    station_id: int
    amount: float
    payment_method: str
    reference_no: str | None = None
    notes: str | None = None
    is_reversed: bool
    reversed_at: datetime | None = None
    reversed_by: int | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
