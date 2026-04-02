from pydantic import BaseModel


class CustomerCreate(BaseModel):
    name: str
    code: str
    customer_type: str = "individual"
    phone: str | None = None
    address: str | None = None
    credit_limit: float = 0
    station_id: int


class CustomerUpdate(BaseModel):
    name: str | None = None
    customer_type: str | None = None
    phone: str | None = None
    address: str | None = None
    credit_limit: float | None = None


class CustomerResponse(BaseModel):
    id: int
    name: str
    code: str
    customer_type: str
    phone: str | None = None
    address: str | None = None
    credit_limit: float
    outstanding_balance: float
    station_id: int

    class Config:
        from_attributes = True