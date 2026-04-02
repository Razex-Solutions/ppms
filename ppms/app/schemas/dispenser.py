from pydantic import BaseModel, ConfigDict


class DispenserCreate(BaseModel):
    name: str
    code: str
    location: str | None = None
    station_id: int


class DispenserUpdate(BaseModel):
    name: str | None = None
    location: str | None = None


class DispenserResponse(BaseModel):
    id: int
    name: str
    code: str
    location: str | None = None
    station_id: int

    model_config = ConfigDict(from_attributes=True)
