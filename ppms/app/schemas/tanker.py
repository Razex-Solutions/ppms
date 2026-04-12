from datetime import datetime

from pydantic import BaseModel, ConfigDict


class TankerCompartmentCreate(BaseModel):
    code: str
    name: str
    capacity: float
    position: int = 1
    is_active: bool = True


class TankerCompartmentUpdate(BaseModel):
    code: str | None = None
    name: str | None = None
    capacity: float | None = None
    position: int | None = None
    is_active: bool | None = None


class TankerCompartmentResponse(BaseModel):
    id: int
    tanker_id: int
    code: str
    name: str
    capacity: float
    position: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class TankerCreate(BaseModel):
    registration_no: str
    name: str
    capacity: float
    ownership_type: str = "owned"
    owner_name: str | None = None
    status: str = "active"
    station_id: int
    fuel_type_id: int | None = None
    compartments: list[TankerCompartmentCreate] = []


class TankerUpdate(BaseModel):
    name: str | None = None
    capacity: float | None = None
    ownership_type: str | None = None
    owner_name: str | None = None
    status: str | None = None
    fuel_type_id: int | None = None


class TankerResponse(BaseModel):
    id: int
    registration_no: str
    name: str
    capacity: float
    ownership_type: str
    owner_name: str | None = None
    status: str
    organization_id: int
    station_id: int
    fuel_type_id: int | None = None
    compartments: list[TankerCompartmentResponse] = []

    model_config = ConfigDict(from_attributes=True)


class TankerTripCompartmentLoadCreate(BaseModel):
    compartment_id: int
    fuel_type_id: int
    loaded_quantity: float
    purchase_rate: float


class TankerTripCompartmentLoadResponse(BaseModel):
    id: int
    trip_id: int
    compartment_id: int
    fuel_type_id: int
    loaded_quantity: float
    remaining_quantity: float
    purchase_rate: float
    purchase_total: float

    model_config = ConfigDict(from_attributes=True)


class TankerTripDriverAssignmentCreate(BaseModel):
    user_id: int
    assignment_role: str = "driver"


class TankerTripDriverAssignmentResponse(BaseModel):
    id: int
    trip_id: int
    user_id: int
    assignment_role: str

    model_config = ConfigDict(from_attributes=True)


class TankerTripCreate(BaseModel):
    tanker_id: int
    station_id: int | None = None
    supplier_id: int | None = None
    fuel_type_id: int | None = None
    trip_type: str
    linked_tank_id: int | None = None
    destination_name: str | None = None
    notes: str | None = None
    loaded_quantity: float | None = None
    purchase_rate: float | None = None
    compartment_loads: list[TankerTripCompartmentLoadCreate] = []
    driver_assignments: list[TankerTripDriverAssignmentCreate] = []


class TankerDeliveryCreate(BaseModel):
    customer_id: int | None = None
    fuel_type_id: int
    compartment_load_id: int | None = None
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
    transfer_to_tank_id: int | None = None
    transfer_quantity: float | None = None


class TankerDeliveryPaymentCreate(BaseModel):
    amount: float
    payment_method: str | None = None
    reference_no: str | None = None
    notes: str | None = None


class TankerDeliveryPaymentResponse(BaseModel):
    id: int
    delivery_id: int
    amount: float
    payment_method: str | None = None
    reference_no: str | None = None
    notes: str | None = None
    received_by_user_id: int | None = None

    model_config = ConfigDict(from_attributes=True)


class FuelTransferResponse(BaseModel):
    id: int
    station_id: int
    tank_id: int
    tanker_trip_id: int | None = None
    fuel_type_id: int
    quantity: float
    transfer_type: str
    notes: str | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TankerCompartmentLoadResponse(BaseModel):
    compartment_id: int
    code: str
    name: str
    quantity: float


class TankerDeliveryResponse(BaseModel):
    id: int
    trip_id: int
    customer_id: int | None = None
    fuel_type_id: int
    compartment_load_id: int | None = None
    destination_name: str | None = None
    quantity: float
    fuel_rate: float
    fuel_amount: float
    delivery_charge: float
    sale_type: str
    paid_amount: float
    outstanding_amount: float
    payments: list[TankerDeliveryPaymentResponse] = []

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
    organization_id: int
    station_id: int
    supplier_id: int | None = None
    fuel_type_id: int | None = None
    trip_type: str
    status: str
    settlement_status: str
    linked_tank_id: int | None = None
    linked_purchase_id: int | None = None
    transfer_tank_id: int | None = None
    destination_name: str | None = None
    notes: str | None = None
    loaded_quantity: float | None = None
    purchase_rate: float | None = None
    purchase_total: float
    total_quantity: float
    leftover_quantity: float
    transferred_quantity: float
    fuel_revenue: float
    delivery_revenue: float
    expense_total: float
    net_profit: float
    compartment_loads: list[TankerTripCompartmentLoadResponse] = []
    driver_assignments: list[TankerTripDriverAssignmentResponse] = []
    deliveries: list[TankerDeliveryResponse] = []
    expenses: list[TankerTripExpenseResponse] = []
    fuel_transfers: list[FuelTransferResponse] = []
    compartment_plan: list[TankerCompartmentLoadResponse] = []

    model_config = ConfigDict(from_attributes=True)


class TankerWorkspaceSummaryResponse(BaseModel):
    organization_id: int | None = None
    station_id: int | None = None
    tanker_count: int
    active_tanker_count: int
    in_progress_trip_count: int
    completed_trip_count: int
    supplier_to_station_trip_count: int
    supplier_to_customer_trip_count: int
    total_loaded_quantity: float
    total_delivered_quantity: float
    total_leftover_quantity: float
    total_transferred_quantity: float
    total_purchase_value: float
    total_fuel_revenue: float
    total_delivery_revenue: float
    total_expense_value: float
    total_net_profit: float
    ownership_breakdown: dict[str, int]
