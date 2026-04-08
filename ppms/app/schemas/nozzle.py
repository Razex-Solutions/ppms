from pydantic import BaseModel, ConfigDict


class NozzleCreate(BaseModel):
    name: str | None = None
    code: str | None = None
    meter_reading: float = 0
    is_active: bool = True
    dispenser_id: int
    tank_id: int
    fuel_type_id: int


class NozzleUpdate(BaseModel):
    name: str | None = None
    meter_reading: float | None = None
    tank_id: int | None = None
    fuel_type_id: int | None = None
    is_active: bool | None = None


class NozzleResponse(BaseModel):
    id: int
    name: str
    code: str
    meter_reading: float
    current_segment_start_reading: float
    is_active: bool
    dispenser_id: int
    tank_id: int
    fuel_type_id: int

    model_config = ConfigDict(from_attributes=True)
