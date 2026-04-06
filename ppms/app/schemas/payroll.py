from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class PayrollRunCreate(BaseModel):
    station_id: int
    period_start: date
    period_end: date
    notes: str | None = None


class PayrollFinalizeRequest(BaseModel):
    notes: str | None = None


class PayrollLineResponse(BaseModel):
    id: int
    payroll_run_id: int
    user_id: int
    present_days: int
    leave_days: int
    absent_days: int
    payable_days: int
    monthly_salary: float
    gross_amount: float
    attendance_deductions: float
    adjustment_additions: float
    adjustment_deductions: float
    deductions: float
    net_amount: float

    model_config = ConfigDict(from_attributes=True)


class PayrollRunResponse(BaseModel):
    id: int
    station_id: int
    period_start: date
    period_end: date
    status: str
    total_staff: int
    total_gross_amount: float
    total_deductions: float
    total_net_amount: float
    notes: str | None = None
    generated_by_user_id: int
    finalized_by_user_id: int | None = None
    finalized_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
