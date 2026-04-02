from pydantic import BaseModel, ConfigDict


class TankerCreate(BaseModel):
    registration_no: str
    name: str
    capacity: float
    owner_name: str | None = None
    driver_name: str | None = None
    driver_phone: str | None = None
    status: str = "active"
    station_id: int
    fuel_type_id: int


class TankerUpdate(BaseModel):
    name: str | None = None
    capacity: float | None = None
    owner_name: str | None = None
    driver_name: str | None = None
    driver_phone: str | None = None
    status: str | None = None


class TankerResponse(BaseModel):
    id: int
    registration_no: str
    name: str
    capacity: float
    owner_name: str | None = None
    driver_name: str | None = None
    driver_phone: str | None = None
    status: str
    station_id: int
    fuel_type_id: int

    model_config = ConfigDict(from_attributes=True)
