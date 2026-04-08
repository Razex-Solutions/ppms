from datetime import datetime

from pydantic import BaseModel, ConfigDict


class EmployeeProfileCreate(BaseModel):
    station_id: int
    linked_user_id: int | None = None
    full_name: str
    staff_type: str | None = None
    staff_title: str | None = None
    employee_code: str | None = None
    phone: str | None = None
    national_id: str | None = None
    address: str | None = None
    is_active: bool = True
    payroll_enabled: bool = True
    monthly_salary: float = 0.0
    can_login: bool = False
    notes: str | None = None


class EmployeeProfileUpdate(BaseModel):
    station_id: int | None = None
    linked_user_id: int | None = None
    full_name: str | None = None
    staff_type: str | None = None
    staff_title: str | None = None
    employee_code: str | None = None
    phone: str | None = None
    national_id: str | None = None
    address: str | None = None
    is_active: bool | None = None
    payroll_enabled: bool | None = None
    monthly_salary: float | None = None
    can_login: bool | None = None
    notes: str | None = None


class EmployeeProfileResponse(BaseModel):
    id: int
    organization_id: int
    station_id: int
    linked_user_id: int | None = None
    full_name: str
    staff_type: str
    staff_title: str | None = None
    linked_user_role_id: int | None = None
    linked_user_role_name: str | None = None
    employee_code: str | None = None
    phone: str | None = None
    national_id: str | None = None
    address: str | None = None
    is_active: bool
    payroll_enabled: bool
    monthly_salary: float
    can_login: bool
    notes: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
