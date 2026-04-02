from pydantic import BaseModel, ConfigDict


class TankCreate(BaseModel):
    name: str
    code: str
    capacity: float
    current_volume: float = 0
    low_stock_threshold: float = 1000
    location: str | None = None
    station_id: int
    fuel_type_id: int


class TankUpdate(BaseModel):
    name: str | None = None
    capacity: float | None = None
    current_volume: float | None = None
    low_stock_threshold: float | None = None
    location: str | None = None


class TankResponse(BaseModel):
    id: int
    name: str
    code: str
    capacity: float
    current_volume: float
    low_stock_threshold: float
    location: str | None = None
    station_id: int
    fuel_type_id: int

    model_config = ConfigDict(from_attributes=True)
