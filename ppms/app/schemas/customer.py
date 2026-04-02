from datetime import datetime

from pydantic import BaseModel, ConfigDict


class CustomerCreate(BaseModel):
    name: str
    code: str
    customer_type: str = "individual"
    phone: str | None = None
    address: str | None = None
    credit_limit: float = 0
    station_id: int


class CustomerUpdate(BaseModel):
    name: str | None = None
    customer_type: str | None = None
    phone: str | None = None
    address: str | None = None
    credit_limit: float | None = None


class CreditOverrideRequest(BaseModel):
    amount: float
    reason: str | None = None


class CustomerResponse(BaseModel):
    id: int
    name: str
    code: str
    customer_type: str
    phone: str | None = None
    address: str | None = None
    credit_limit: float
    outstanding_balance: float
    credit_override_status: str | None = None
    credit_override_amount: float = 0
    credit_override_requested_amount: float = 0
    credit_override_requested_at: datetime | None = None
    credit_override_requested_by: int | None = None
    credit_override_reason: str | None = None
    credit_override_reviewed_at: datetime | None = None
    credit_override_reviewed_by: int | None = None
    credit_override_rejection_reason: str | None = None
    station_id: int

    model_config = ConfigDict(from_attributes=True)
