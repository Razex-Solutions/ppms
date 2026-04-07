from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, field_validator


class SalaryAdjustmentBase(BaseModel):
    user_id: int | None = None
    employee_profile_id: int | None = None
    effective_date: date
    impact: str
    amount: float
    reason: str
    notes: str | None = None

    @field_validator("impact")
    @classmethod
    def validate_impact(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"addition", "deduction"}:
            raise ValueError("Impact must be either addition or deduction")
        return normalized

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, value: float) -> float:
        rounded = round(float(value), 2)
        if rounded <= 0:
            raise ValueError("Amount must be greater than zero")
        return rounded

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Reason is required")
        return normalized

    @field_validator("notes")
    @classmethod
    def validate_notes(cls, value: str | None) -> str | None:
        if value is None:
            return value
        normalized = value.strip()
        return normalized or None


class SalaryAdjustmentCreate(SalaryAdjustmentBase):
    station_id: int


class SalaryAdjustmentResponse(BaseModel):
    id: int
    station_id: int
    user_id: int | None = None
    employee_profile_id: int | None = None
    effective_date: date
    impact: str
    amount: float
    reason: str
    notes: str | None = None
    created_by_user_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
