from pydantic import BaseModel, ConfigDict


class SupplierCreate(BaseModel):
    name: str
    code: str
    phone: str | None = None
    address: str | None = None


class SupplierUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    address: str | None = None


class SupplierResponse(BaseModel):
    id: int
    name: str
    code: str
    phone: str | None = None
    address: str | None = None
    payable_balance: float

    model_config = ConfigDict(from_attributes=True)
