from pydantic import BaseModel, ConfigDict


class DispenserCreate(BaseModel):
    name: str | None = None
    code: str | None = None
    location: str | None = None
    is_active: bool = True
    station_id: int


class DispenserUpdate(BaseModel):
    name: str | None = None
    location: str | None = None
    is_active: bool | None = None


class DispenserResponse(BaseModel):
    id: int
    name: str
    code: str
    location: str | None = None
    is_active: bool
    station_id: int

    model_config = ConfigDict(from_attributes=True)
