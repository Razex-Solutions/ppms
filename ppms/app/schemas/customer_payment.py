from pydantic import BaseModel, ConfigDict
from datetime import datetime


class CustomerPaymentCreate(BaseModel):
    customer_id: int
    station_id: int
    amount: float
    payment_method: str = "cash"
    reference_no: str | None = None
    notes: str | None = None


class ReversalRequest(BaseModel):
    reason: str | None = None


class CustomerPaymentResponse(BaseModel):
    id: int
    customer_id: int
    station_id: int
    amount: float
    payment_method: str
    reference_no: str | None = None
    notes: str | None = None
    is_reversed: bool
    reversal_request_status: str | None = None
    reversal_requested_at: datetime | None = None
    reversal_requested_by: int | None = None
    reversal_request_reason: str | None = None
    reversal_reviewed_at: datetime | None = None
    reversal_reviewed_by: int | None = None
    reversal_rejection_reason: str | None = None
    reversed_at: datetime | None = None
    reversed_by: int | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
