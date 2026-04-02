from pydantic import BaseModel, ConfigDict
from datetime import datetime


class ExpenseCreate(BaseModel):
    title: str
    category: str
    amount: float
    notes: str | None = None
    station_id: int


class ExpenseUpdate(BaseModel):
    title: str | None = None
    category: str | None = None
    amount: float | None = None
    notes: str | None = None


class ExpenseApprovalRequest(BaseModel):
    reason: str | None = None


class ExpenseResponse(BaseModel):
    id: int
    title: str
    category: str
    amount: float
    notes: str | None = None
    station_id: int
    status: str
    submitted_by_user_id: int | None = None
    approved_by_user_id: int | None = None
    approved_at: datetime | None = None
    rejected_at: datetime | None = None
    rejection_reason: str | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
