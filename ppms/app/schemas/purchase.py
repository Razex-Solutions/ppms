from pydantic import BaseModel, ConfigDict
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


class ReversalRequest(BaseModel):
    reason: str | None = None


class PurchaseApprovalRequest(BaseModel):
    reason: str | None = None


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
    status: str
    submitted_by_user_id: int | None = None
    approved_by_user_id: int | None = None
    approved_at: datetime | None = None
    rejected_at: datetime | None = None
    rejection_reason: str | None = None
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
