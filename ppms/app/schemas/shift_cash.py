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
    lubricant_cash_sales: float = 0.0
    credit_recoveries: float = 0.0
    credit_given: float = 0.0
    cash_expenses: float = 0.0
    expected_cash: float
    accountable_cash: float = 0.0
    cash_submitted: float
    closing_cash: float | None = None
    difference: float | None = None
    cash_in_hand: float
    notes: str | None = None
    created_at: datetime
    submission_count: int

    model_config = ConfigDict(from_attributes=True)
