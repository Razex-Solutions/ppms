from pydantic import BaseModel


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

    class Config:
        from_attributes = True