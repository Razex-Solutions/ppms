from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, require_station_access
from app.core.time import utc_now
from app.models.attendance_record import AttendanceRecord
from app.models.payroll_line import PayrollLine
from app.models.payroll_run import PayrollRun
from app.models.station import Station
from app.models.user import User
from app.schemas.payroll import PayrollRunCreate
from app.services.audit import log_audit_event


def ensure_payroll_access(db: Session, station_id: int, current_user: User) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if current_user.role.name == "Admin":
        return station
    if is_head_office_user(current_user):
        if station.organization_id == get_user_organization_id(current_user):
            return station
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    require_station_access(current_user, station_id)
    return station


def _date_count(start_date, end_date) -> int:
    return (end_date - start_date).days + 1


def create_payroll_run(db: Session, *, data: PayrollRunCreate, current_user: User) -> PayrollRun:
    ensure_payroll_access(db, data.station_id, current_user)
    if data.period_end < data.period_start:
        raise HTTPException(status_code=400, detail="Payroll period end must be after the start date")

    existing = (
        db.query(PayrollRun)
        .filter(
            PayrollRun.station_id == data.station_id,
            PayrollRun.period_start == data.period_start,
            PayrollRun.period_end == data.period_end,
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Payroll run already exists for this station and period")

    users = (
        db.query(User)
        .filter(
            User.station_id == data.station_id,
            User.is_active.is_(True),
            User.payroll_enabled.is_(True),
        )
        .all()
    )
    period_days = _date_count(data.period_start, data.period_end)
    payroll_run = PayrollRun(
        station_id=data.station_id,
        period_start=data.period_start,
        period_end=data.period_end,
        status="draft",
        notes=data.notes,
        generated_by_user_id=current_user.id,
    )
    db.add(payroll_run)
    db.flush()

    total_gross = 0.0
    total_deductions = 0.0
    total_net = 0.0
    total_staff = 0

    for user in users:
        records = (
            db.query(AttendanceRecord)
            .filter(
                AttendanceRecord.user_id == user.id,
                AttendanceRecord.station_id == data.station_id,
                AttendanceRecord.attendance_date >= data.period_start,
                AttendanceRecord.attendance_date <= data.period_end,
            )
            .all()
        )
        present_days = sum(1 for record in records if record.status == "present")
        leave_days = sum(1 for record in records if record.status == "leave")
        half_days = sum(1 for record in records if record.status == "half_day")
        payable_days = present_days + leave_days + half_days
        absent_days = max(period_days - payable_days, 0)
        monthly_salary = round(user.monthly_salary or 0.0, 2)
        gross_amount = round((monthly_salary / 30.0) * (present_days + leave_days + (half_days * 0.5)), 2)
        deduction_amount = round((monthly_salary / 30.0) * max(absent_days - leave_days, 0), 2) if monthly_salary else 0.0
        net_amount = max(round(gross_amount - deduction_amount, 2), 0.0)

        line = PayrollLine(
            payroll_run_id=payroll_run.id,
            user_id=user.id,
            present_days=present_days,
            leave_days=leave_days,
            absent_days=absent_days,
            payable_days=payable_days,
            monthly_salary=monthly_salary,
            gross_amount=gross_amount,
            deductions=deduction_amount,
            net_amount=net_amount,
        )
        db.add(line)
        total_staff += 1
        total_gross += gross_amount
        total_deductions += deduction_amount
        total_net += net_amount

    payroll_run.total_staff = total_staff
    payroll_run.total_gross_amount = round(total_gross, 2)
    payroll_run.total_deductions = round(total_deductions, 2)
    payroll_run.total_net_amount = round(total_net, 2)

    log_audit_event(
        db,
        current_user=current_user,
        module="payroll",
        action="payroll.create_run",
        entity_type="payroll_run",
        entity_id=payroll_run.id,
        station_id=payroll_run.station_id,
    )
    db.commit()
    db.refresh(payroll_run)
    return payroll_run


def finalize_payroll_run(db: Session, *, payroll_run: PayrollRun, current_user: User, notes: str | None = None) -> PayrollRun:
    ensure_payroll_access(db, payroll_run.station_id, current_user)
    if payroll_run.status == "finalized":
        raise HTTPException(status_code=400, detail="Payroll run is already finalized")
    payroll_run.status = "finalized"
    payroll_run.finalized_by_user_id = current_user.id
    payroll_run.finalized_at = utc_now()
    if notes:
        payroll_run.notes = notes
    log_audit_event(
        db,
        current_user=current_user,
        module="payroll",
        action="payroll.finalize_run",
        entity_type="payroll_run",
        entity_id=payroll_run.id,
        station_id=payroll_run.station_id,
    )
    db.commit()
    db.refresh(payroll_run)
    return payroll_run
