from pydantic import BaseModel


class FuelTypeCreate(BaseModel):
    name: str
    description: str | None = None


class FuelTypeUpdate(BaseModel):
    name: str | None = None
    description: str | None = None


class FuelTypeResponse(BaseModel):
    id: int
    name: str
    description: str | None = None

    class Config:
        from_attributes = True