from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class AttendanceCheckInRequest(BaseModel):
    station_id: int
    notes: str | None = None


class AttendanceSelfCheckInRequest(BaseModel):
    notes: str | None = None


class AttendanceCheckOutRequest(BaseModel):
    notes: str | None = None


class AttendanceSelfCheckOutRequest(BaseModel):
    notes: str | None = None


class AttendanceRecordCreate(BaseModel):
    user_id: int | None = None
    employee_profile_id: int | None = None
    station_id: int
    attendance_date: date
    status: str = "present"
    check_in_at: datetime | None = None
    check_out_at: datetime | None = None
    notes: str | None = None


class AttendanceRecordUpdate(BaseModel):
    status: str | None = None
    check_in_at: datetime | None = None
    check_out_at: datetime | None = None
    notes: str | None = None


class AttendanceRecordResponse(BaseModel):
    id: int
    station_id: int
    user_id: int | None = None
    employee_profile_id: int | None = None
    attendance_date: date
    status: str
    check_in_at: datetime | None = None
    check_out_at: datetime | None = None
    notes: str | None = None
    approved_by_user_id: int | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AttendanceSelfServiceSummaryResponse(BaseModel):
    enabled: bool
    station_id: int | None = None
    station_name: str | None = None
    today_record: AttendanceRecordResponse | None = None
    recent_records: list[AttendanceRecordResponse]
