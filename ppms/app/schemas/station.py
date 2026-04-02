from pydantic import BaseModel, ConfigDict


class StationCreate(BaseModel):
    name: str
    code: str
    address: str | None = None
    city: str | None = None


class StationUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    address: str | None = None
    city: str | None = None


class StationResponse(BaseModel):
    id: int
    name: str
    code: str
    address: str | None = None
    city: str | None = None

    model_config = ConfigDict(from_attributes=True)
