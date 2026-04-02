from pydantic import BaseModel


class NozzleCreate(BaseModel):
    name: str
    code: str
    meter_reading: float = 0
    dispenser_id: int
    tank_id: int
    fuel_type_id: int


class NozzleUpdate(BaseModel):
    name: str | None = None
    meter_reading: float | None = None
    tank_id: int | None = None
    fuel_type_id: int | None = None


class NozzleResponse(BaseModel):
    id: int
    name: str
    code: str
    meter_reading: float
    dispenser_id: int
    tank_id: int
    fuel_type_id: int

    class Config:
        from_attributes = True