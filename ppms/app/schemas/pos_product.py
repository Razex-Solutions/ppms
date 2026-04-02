from pydantic import BaseModel, ConfigDict


class POSProductCreate(BaseModel):
    name: str
    code: str
    category: str
    module: str
    price: float
    stock_quantity: float = 0.0
    track_inventory: bool = True
    is_active: bool = True
    station_id: int


class POSProductUpdate(BaseModel):
    name: str | None = None
    category: str | None = None
    module: str | None = None
    price: float | None = None
    stock_quantity: float | None = None
    track_inventory: bool | None = None
    is_active: bool | None = None


class POSProductResponse(BaseModel):
    id: int
    name: str
    code: str
    category: str
    module: str
    price: float
    stock_quantity: float
    track_inventory: bool
    is_active: bool
    station_id: int

    model_config = ConfigDict(from_attributes=True)
