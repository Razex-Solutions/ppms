from pydantic import BaseModel, ConfigDict


class TankerCreate(BaseModel):
    registration_no: str
    name: str
    capacity: float
    ownership_type: str = "owned"
    owner_name: str | None = None
    driver_name: str | None = None
    driver_phone: str | None = None
    status: str = "active"
    station_id: int
    fuel_type_id: int


class TankerUpdate(BaseModel):
    name: str | None = None
    capacity: float | None = None
    ownership_type: str | None = None
    owner_name: str | None = None
    driver_name: str | None = None
    driver_phone: str | None = None
    status: str | None = None


class TankerResponse(BaseModel):
    id: int
    registration_no: str
    name: str
    capacity: float
    ownership_type: str
    owner_name: str | None = None
    driver_name: str | None = None
    driver_phone: str | None = None
    status: str
    station_id: int
    fuel_type_id: int

    model_config = ConfigDict(from_attributes=True)


class TankerTripCreate(BaseModel):
    tanker_id: int
    supplier_id: int | None = None
    fuel_type_id: int
    trip_type: str
    linked_tank_id: int | None = None
    destination_name: str | None = None
    notes: str | None = None


class TankerDeliveryCreate(BaseModel):
    customer_id: int | None = None
    destination_name: str | None = None
    quantity: float
    fuel_rate: float
    delivery_charge: float = 0
    sale_type: str = "cash"
    paid_amount: float = 0


class TankerTripExpenseCreate(BaseModel):
    expense_type: str
    amount: float
    notes: str | None = None


class TankerTripComplete(BaseModel):
    reason: str | None = None


class TankerDeliveryResponse(BaseModel):
    id: int
    trip_id: int
    customer_id: int | None = None
    destination_name: str | None = None
    quantity: float
    fuel_rate: float
    fuel_amount: float
    delivery_charge: float
    sale_type: str
    paid_amount: float
    outstanding_amount: float

    model_config = ConfigDict(from_attributes=True)


class TankerTripExpenseResponse(BaseModel):
    id: int
    trip_id: int
    expense_type: str
    amount: float
    notes: str | None = None

    model_config = ConfigDict(from_attributes=True)


class TankerTripResponse(BaseModel):
    id: int
    tanker_id: int
    station_id: int
    supplier_id: int | None = None
    fuel_type_id: int
    trip_type: str
    status: str
    settlement_status: str
    linked_tank_id: int | None = None
    linked_purchase_id: int | None = None
    destination_name: str | None = None
    notes: str | None = None
    total_quantity: float
    fuel_revenue: float
    delivery_revenue: float
    expense_total: float
    net_profit: float
    deliveries: list[TankerDeliveryResponse] = []
    expenses: list[TankerTripExpenseResponse] = []

    model_config = ConfigDict(from_attributes=True)
