from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.attendance_record import AttendanceRecord
from app.models.employee_profile import EmployeeProfile
from app.models.user import User
from app.schemas.attendance import (
    AttendanceCheckInRequest,
    AttendanceCheckOutRequest,
    AttendanceRecordCreate,
    AttendanceRecordResponse,
    AttendanceSelfCheckInRequest,
    AttendanceSelfCheckOutRequest,
    AttendanceSelfServiceSummaryResponse,
    AttendanceRecordUpdate,
)
from app.services.attendance import (
    check_in,
    check_out,
    create_attendance_record,
    ensure_attendance_access,
    update_attendance_record,
)
from app.core.time import utc_now


router = APIRouter(prefix="/attendance", tags=["Attendance"])


def _get_current_user_open_attendance(db: Session, current_user: User) -> AttendanceRecord | None:
    return (
        db.query(AttendanceRecord)
        .filter(
            AttendanceRecord.user_id == current_user.id,
            AttendanceRecord.station_id == current_user.station_id,
            AttendanceRecord.check_out_at.is_(None),
        )
        .order_by(AttendanceRecord.attendance_date.desc(), AttendanceRecord.id.desc())
        .first()
    )


@router.post("/check-in", response_model=AttendanceRecordResponse)
def post_check_in(
    data: AttendanceCheckInRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "attendance", "check_in", detail="You do not have permission to check in")
    return check_in(db, current_user=current_user, station_id=data.station_id, notes=data.notes)


@router.get("/me", response_model=AttendanceSelfServiceSummaryResponse)
def get_my_attendance_summary(
    limit: int = Query(14, ge=1, le=60),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    today = utc_now().date()
    recent_records = (
        db.query(AttendanceRecord)
        .filter(AttendanceRecord.user_id == current_user.id)
        .order_by(AttendanceRecord.attendance_date.desc(), AttendanceRecord.id.desc())
        .limit(limit)
        .all()
    )
    today_record = next((record for record in recent_records if record.attendance_date == today), None)
    return AttendanceSelfServiceSummaryResponse(
        enabled=bool(current_user.station_id),
        station_id=current_user.station_id,
        station_name=current_user.station.name if current_user.station is not None else None,
        today_record=today_record,
        recent_records=recent_records,
    )


@router.post("/me/check-in", response_model=AttendanceRecordResponse)
def post_my_check_in(
    data: AttendanceSelfCheckInRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "attendance", "check_in", detail="You do not have permission to check in")
    if current_user.station_id is None:
        raise HTTPException(status_code=400, detail="Your account is not assigned to a station")
    return check_in(db, current_user=current_user, station_id=current_user.station_id, notes=data.notes)


@router.post("/{attendance_id}/check-out", response_model=AttendanceRecordResponse)
def post_check_out(
    attendance_id: int,
    data: AttendanceCheckOutRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = db.query(AttendanceRecord).filter(AttendanceRecord.id == attendance_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Attendance record not found")
    require_permission(current_user, "attendance", "check_out", detail="You do not have permission to check out")
    return check_out(db, record=record, current_user=current_user, notes=data.notes)


@router.post("/me/check-out", response_model=AttendanceRecordResponse)
def post_my_check_out(
    data: AttendanceSelfCheckOutRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "attendance", "check_out", detail="You do not have permission to check out")
    if current_user.station_id is None:
        raise HTTPException(status_code=400, detail="Your account is not assigned to a station")
    record = _get_current_user_open_attendance(db, current_user)
    if record is None:
        raise HTTPException(status_code=404, detail="No open attendance record found for today")
    return check_out(db, record=record, current_user=current_user, notes=data.notes)


@router.post("/", response_model=AttendanceRecordResponse)
def post_attendance_record(
    data: AttendanceRecordCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "attendance", "create", detail="You do not have permission to create attendance records")
    return create_attendance_record(db, data=data, current_user=current_user)


@router.get("/", response_model=list[AttendanceRecordResponse])
def list_attendance(
    station_id: int | None = Query(None),
    user_id: int | None = Query(None),
    attendance_date: date | None = Query(None),
    status: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "attendance", "read", detail="You do not have permission to view attendance")
    query = db.query(AttendanceRecord)
    if is_master_admin(current_user):
        pass
    elif current_user.role.name == "HeadOffice":
        organization_id = current_user.organization_id or (current_user.station.organization_id if current_user.station else None)
        query = query.outerjoin(User, User.id == AttendanceRecord.user_id).outerjoin(
            EmployeeProfile,
            EmployeeProfile.id == AttendanceRecord.employee_profile_id,
        ).filter(
            (User.station.has(organization_id=organization_id))
            | (EmployeeProfile.organization_id == organization_id)
        )
    else:
        station_id = current_user.station_id
    if station_id is not None:
        query = query.filter(AttendanceRecord.station_id == station_id)
    if user_id is not None:
        query = query.filter(AttendanceRecord.user_id == user_id)
    if attendance_date is not None:
        query = query.filter(AttendanceRecord.attendance_date == attendance_date)
    if status is not None:
        query = query.filter(AttendanceRecord.status == status)
    return query.order_by(AttendanceRecord.attendance_date.desc(), AttendanceRecord.id.desc()).offset(skip).limit(limit).all()


@router.get("/{attendance_id}", response_model=AttendanceRecordResponse)
def get_attendance_record(
    attendance_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "attendance", "read", detail="You do not have permission to view attendance")
    record = db.query(AttendanceRecord).filter(AttendanceRecord.id == attendance_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Attendance record not found")
    ensure_attendance_access(db, record.station_id, current_user)
    return record


@router.put("/{attendance_id}", response_model=AttendanceRecordResponse)
def put_attendance_record(
    attendance_id: int,
    data: AttendanceRecordUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "attendance", "update", detail="You do not have permission to update attendance")
    record = db.query(AttendanceRecord).filter(AttendanceRecord.id == attendance_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Attendance record not found")
    return update_attendance_record(db, record=record, data=data, current_user=current_user)
