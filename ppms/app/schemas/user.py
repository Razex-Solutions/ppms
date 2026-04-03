from pydantic import BaseModel, ConfigDict, EmailStr


class UserCreate(BaseModel):
    full_name: str
    username: str
    email: EmailStr | None = None
    password: str
    role_id: int
    station_id: int | None = None
    monthly_salary: float = 0
    payroll_enabled: bool = True


class UserUpdate(BaseModel):
    full_name: str | None = None
    email: EmailStr | None = None
    is_active: bool | None = None
    role_id: int | None = None
    station_id: int | None = None
    monthly_salary: float | None = None
    payroll_enabled: bool | None = None


class UserResponse(BaseModel):
    id: int
    full_name: str
    username: str
    email: EmailStr | None = None
    is_active: bool
    role_id: int
    station_id: int | None = None
    organization_id: int | None = None
    monthly_salary: float
    payroll_enabled: bool

    model_config = ConfigDict(from_attributes=True)
