from datetime import date

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_station_access
from app.core.time import utc_now
from app.models.attendance_record import AttendanceRecord
from app.models.station import Station
from app.models.user import User
from app.schemas.attendance import AttendanceRecordCreate, AttendanceRecordUpdate
from app.services.audit import log_audit_event


VALID_ATTENDANCE_STATUSES = {"present", "absent", "leave", "half_day"}


def ensure_attendance_access(db: Session, station_id: int, current_user: User) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return station
    if is_head_office_user(current_user):
        if station.organization_id == get_user_organization_id(current_user):
            return station
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    require_station_access(current_user, station_id)
    return station


def _validate_status(status: str) -> None:
    if status not in VALID_ATTENDANCE_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid attendance status")


def check_in(db: Session, *, current_user: User, station_id: int, notes: str | None = None) -> AttendanceRecord:
    ensure_attendance_access(db, station_id, current_user)
    today = utc_now().date()
    existing = (
        db.query(AttendanceRecord)
        .filter(
            AttendanceRecord.user_id == current_user.id,
            AttendanceRecord.station_id == station_id,
            AttendanceRecord.attendance_date == today,
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Attendance already recorded for today")
    record = AttendanceRecord(
        user_id=current_user.id,
        station_id=station_id,
        attendance_date=today,
        status="present",
        check_in_at=utc_now(),
        notes=notes,
    )
    db.add(record)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="attendance",
        action="attendance.check_in",
        entity_type="attendance_record",
        entity_id=record.id,
        station_id=station_id,
    )
    db.commit()
    db.refresh(record)
    return record


def check_out(db: Session, *, record: AttendanceRecord, current_user: User, notes: str | None = None) -> AttendanceRecord:
    if current_user.role.name != "Admin" and not is_master_admin(current_user) and record.user_id != current_user.id:
        require_station_access(current_user, record.station_id)
    if record.check_out_at is not None:
        raise HTTPException(status_code=400, detail="Attendance is already checked out")
    record.check_out_at = utc_now()
    if notes:
        record.notes = notes
    log_audit_event(
        db,
        current_user=current_user,
        module="attendance",
        action="attendance.check_out",
        entity_type="attendance_record",
        entity_id=record.id,
        station_id=record.station_id,
    )
    db.commit()
    db.refresh(record)
    return record


def create_attendance_record(db: Session, *, data: AttendanceRecordCreate, current_user: User) -> AttendanceRecord:
    ensure_attendance_access(db, data.station_id, current_user)
    _validate_status(data.status)
    user = db.query(User).filter(User.id == data.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.station_id != data.station_id:
        raise HTTPException(status_code=400, detail="User does not belong to the selected station")
    existing = (
        db.query(AttendanceRecord)
        .filter(
            AttendanceRecord.user_id == data.user_id,
            AttendanceRecord.station_id == data.station_id,
            AttendanceRecord.attendance_date == data.attendance_date,
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Attendance already exists for this user and date")
    record = AttendanceRecord(**data.model_dump(), approved_by_user_id=current_user.id)
    db.add(record)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="attendance",
        action="attendance.create",
        entity_type="attendance_record",
        entity_id=record.id,
        station_id=record.station_id,
    )
    db.commit()
    db.refresh(record)
    return record


def update_attendance_record(db: Session, *, record: AttendanceRecord, data: AttendanceRecordUpdate, current_user: User) -> AttendanceRecord:
    ensure_attendance_access(db, record.station_id, current_user)
    payload = data.model_dump(exclude_unset=True)
    if "status" in payload:
        _validate_status(payload["status"])
    for field, value in payload.items():
        setattr(record, field, value)
    record.approved_by_user_id = current_user.id
    log_audit_event(
        db,
        current_user=current_user,
        module="attendance",
        action="attendance.update",
        entity_type="attendance_record",
        entity_id=record.id,
        station_id=record.station_id,
        details=payload,
    )
    db.commit()
    db.refresh(record)
    return record
