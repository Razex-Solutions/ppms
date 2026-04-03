from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class AttendanceCheckInRequest(BaseModel):
    station_id: int
    notes: str | None = None


class AttendanceCheckOutRequest(BaseModel):
    notes: str | None = None


class AttendanceRecordCreate(BaseModel):
    user_id: int
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
    user_id: int
    attendance_date: date
    status: str
    check_in_at: datetime | None = None
    check_out_at: datetime | None = None
    notes: str | None = None
    approved_by_user_id: int | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
