from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CashSubmissionCreate(BaseModel):
    amount: float = Field(gt=0)
    notes: str | None = None


class CashSubmissionResponse(BaseModel):
    id: int
    shift_cash_id: int
    amount: float
    submitted_by: int
    submitted_at: datetime
    notes: str | None = None

    model_config = ConfigDict(from_attributes=True)


class ShiftCashResponse(BaseModel):
    id: int
    station_id: int
    shift_id: int
    manager_id: int
    opening_cash: float
    cash_sales: float
    expected_cash: float
    cash_submitted: float
    closing_cash: float | None = None
    difference: float | None = None
    notes: str | None = None
    created_at: datetime
    submission_count: int

    model_config = ConfigDict(from_attributes=True)
