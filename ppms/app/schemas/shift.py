from pydantic import BaseModel, ConfigDict
from datetime import datetime, time


class ShiftCreate(BaseModel):
    station_id: int
    shift_template_id: int | None = None
    initial_cash: float = 0.0
    notes: str | None = None


class ShiftUpdate(BaseModel):
    actual_cash_collected: float
    nozzle_readings: list["ShiftCloseNozzleReading"] = []
    notes: str | None = None


class ShiftResponse(BaseModel):
    id: int
    station_id: int
    user_id: int
    shift_template_id: int | None = None
    shift_name: str | None = None
    start_time: datetime
    end_time: datetime | None = None
    status: str
    initial_cash: float
    total_sales_cash: float
    total_sales_credit: float
    expected_cash: float
    actual_cash_collected: float | None = None
    difference: float | None = None
    notes: str | None = None

    model_config = ConfigDict(from_attributes=True)


class ShiftTemplateSummaryResponse(BaseModel):
    id: int
    station_id: int
    name: str
    start_time: time
    end_time: time
    is_active: bool
    covers_full_day: bool
    window_label: str


class CurrentShiftNozzleOpeningResponse(BaseModel):
    nozzle_id: int
    nozzle_name: str
    nozzle_code: str
    dispenser_id: int
    dispenser_name: str
    fuel_type_id: int
    fuel_type_name: str | None = None
    tank_id: int
    tank_name: str | None = None
    opening_meter: float
    current_meter: float
    has_meter_adjustment_history: bool = False


class CurrentShiftDispenserGroupResponse(BaseModel):
    dispenser_id: int
    dispenser_name: str
    dispenser_code: str
    nozzles: list[CurrentShiftNozzleOpeningResponse]


class CurrentShiftWorkspaceResponse(BaseModel):
    station_id: int
    manager_user_id: int
    active_manager_user_id: int | None = None
    active_manager_name: str | None = None
    shift_date: datetime
    status: str
    message: str
    active_shift: ShiftResponse | None = None
    matched_template: ShiftTemplateSummaryResponse | None = None
    opening_cash_preview: float | None = None
    opening_nozzle_groups: list[CurrentShiftDispenserGroupResponse] = []
    requires_manual_open: bool = False


class ShiftCloseNozzleReading(BaseModel):
    nozzle_id: int
    closing_meter: float


class ShiftCloseValidationIssueResponse(BaseModel):
    code: str
    title: str
    detail: str
    blocking: bool
    nozzle_id: int | None = None
    tank_id: int | None = None
    usage_liters: float | None = None


class ShiftCloseValidationResponse(BaseModel):
    shift_id: int
    can_close: bool
    blocking_issue_count: int
    warning_count: int
    issues: list[ShiftCloseValidationIssueResponse]
