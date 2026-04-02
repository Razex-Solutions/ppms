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


class ExpenseResponse(BaseModel):
    id: int
    title: str
    category: str
    amount: float
    notes: str | None = None
    station_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
