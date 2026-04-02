from pydantic import BaseModel


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

    class Config:
        from_attributes = True