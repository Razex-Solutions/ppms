from pydantic import BaseModel, ConfigDict, EmailStr


class UserCreate(BaseModel):
    full_name: str
    username: str
    email: EmailStr | None = None
    password: str
    role_id: int
    station_id: int | None = None


class UserUpdate(BaseModel):
    full_name: str | None = None
    email: EmailStr | None = None
    is_active: bool | None = None
    role_id: int | None = None
    station_id: int | None = None


class UserResponse(BaseModel):
    id: int
    full_name: str
    username: str
    email: EmailStr | None = None
    is_active: bool
    role_id: int
    station_id: int | None = None

    model_config = ConfigDict(from_attributes=True)
