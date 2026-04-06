from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.time import utc_now
from app.models.fuel_sale import FuelSale
from app.models.cash_submission import CashSubmission
from app.models.shift import Shift
from app.models.shift_cash import ShiftCash
from app.models.station import Station
from app.models.station_shift_template import StationShiftTemplate
from app.models.user import User
from app.schemas.shift import ShiftCreate, ShiftUpdate
from app.schemas.shift_cash import CashSubmissionCreate
from app.services.audit import log_audit_event


def create_shift(db: Session, data: ShiftCreate, current_user: User) -> Shift:
    if current_user.role.name != "Admin" and not is_master_admin(current_user) and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    existing = db.query(Shift).filter(
        Shift.user_id == current_user.id,
        Shift.station_id == data.station_id,
        Shift.status == "open",
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"You already have an open shift (ID: {existing.id}) at this station")

    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    shift_template = None
    if data.shift_template_id is not None:
        shift_template = db.query(StationShiftTemplate).filter(
            StationShiftTemplate.id == data.shift_template_id,
            StationShiftTemplate.station_id == data.station_id,
        ).first()
        if not shift_template:
            raise HTTPException(status_code=404, detail="Shift template not found for this station")
        if not shift_template.is_active:
            raise HTTPException(status_code=400, detail="Selected shift template is inactive")

    shift = Shift(
        station_id=data.station_id,
        user_id=current_user.id,
        shift_template_id=shift_template.id if shift_template else None,
        shift_name=shift_template.name if shift_template else None,
        initial_cash=data.initial_cash,
        expected_cash=data.initial_cash,
        notes=data.notes,
        status="open",
        start_time=utc_now(),
    )
    db.add(shift)
    db.flush()
    shift_cash = ShiftCash(
        station_id=shift.station_id,
        shift_id=shift.id,
        manager_id=current_user.id,
        opening_cash=shift.initial_cash,
        expected_cash=shift.initial_cash,
        notes=shift.notes,
    )
    db.add(shift_cash)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="shifts",
        action="shifts.open",
        entity_type="shift",
        entity_id=shift.id,
        station_id=shift.station_id,
        details={
            "initial_cash": shift.initial_cash,
            "shift_template_id": shift.shift_template_id,
            "shift_name": shift.shift_name,
        },
    )
    db.commit()
    db.refresh(shift)
    return shift


def close_shift(db: Session, shift: Shift, data: ShiftUpdate, current_user: User) -> Shift:
    if shift.status == "closed":
        raise HTTPException(status_code=400, detail="Shift is already closed")
    if shift.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only close your own shifts")

    sales = db.query(FuelSale).filter(
        FuelSale.shift_id == shift.id,
        FuelSale.is_reversed.is_(False),
    ).all()
    total_cash = sum(s.total_amount for s in sales if s.sale_type == "cash")
    total_credit = sum(s.total_amount for s in sales if s.sale_type == "credit")
    shift_cash = ensure_shift_cash(db, shift)

    shift.total_sales_cash = total_cash
    shift.total_sales_credit = total_credit
    shift.expected_cash = shift.initial_cash + total_cash
    shift.actual_cash_collected = data.actual_cash_collected
    shift.difference = shift.actual_cash_collected - shift.expected_cash
    shift.status = "closed"
    shift.end_time = utc_now()
    shift.notes = data.notes if data.notes else shift.notes
    shift_cash.cash_sales = total_cash
    shift_cash.expected_cash = shift.expected_cash
    shift_cash.closing_cash = data.actual_cash_collected
    submission_total = sum(submission.amount for submission in shift_cash.submissions)
    shift_cash.cash_submitted = submission_total if submission_total > 0 else data.actual_cash_collected
    shift_cash.difference = shift.actual_cash_collected - shift.expected_cash
    shift_cash.notes = data.notes if data.notes else shift_cash.notes
    log_audit_event(
        db,
        current_user=current_user,
        module="shifts",
        action="shifts.close",
        entity_type="shift",
        entity_id=shift.id,
        station_id=shift.station_id,
        details={
            "expected_cash": shift.expected_cash,
            "actual_cash_collected": shift.actual_cash_collected,
            "difference": shift.difference,
        },
    )
    db.commit()
    db.refresh(shift)
    return shift


def ensure_shift_cash(db: Session, shift: Shift) -> ShiftCash:
    shift_cash = db.query(ShiftCash).filter(ShiftCash.shift_id == shift.id).first()
    if shift_cash:
        return shift_cash

    shift_cash = ShiftCash(
        station_id=shift.station_id,
        shift_id=shift.id,
        manager_id=shift.user_id,
        opening_cash=shift.initial_cash,
        cash_sales=shift.total_sales_cash or 0.0,
        expected_cash=shift.expected_cash or shift.initial_cash,
        cash_submitted=shift.actual_cash_collected or 0.0,
        closing_cash=shift.actual_cash_collected,
        difference=shift.difference,
        notes=shift.notes,
    )
    db.add(shift_cash)
    db.flush()
    return shift_cash


def list_cash_submissions(db: Session, shift: Shift) -> list[CashSubmission]:
    shift_cash = ensure_shift_cash(db, shift)
    return (
        db.query(CashSubmission)
        .filter(CashSubmission.shift_cash_id == shift_cash.id)
        .order_by(CashSubmission.submitted_at.asc(), CashSubmission.id.asc())
        .all()
    )


def create_cash_submission(
    db: Session,
    shift: Shift,
    data: CashSubmissionCreate,
    current_user: User,
) -> CashSubmission:
    if shift.status == "closed":
        raise HTTPException(status_code=400, detail="Cannot record a cash submission for a closed shift")

    shift_cash = ensure_shift_cash(db, shift)
    submission = CashSubmission(
        shift_cash_id=shift_cash.id,
        amount=data.amount,
        submitted_by=current_user.id,
        notes=data.notes,
    )
    db.add(submission)
    db.flush()

    shift_cash.cash_submitted = (shift_cash.cash_submitted or 0.0) + data.amount

    log_audit_event(
        db,
        current_user=current_user,
        module="shifts",
        action="shifts.cash_submission",
        entity_type="cash_submission",
        entity_id=submission.id,
        station_id=shift.station_id,
        details={
            "shift_id": shift.id,
            "amount": submission.amount,
        },
    )
    db.commit()
    db.refresh(submission)
    return submission


def ensure_shift_access(shift: Shift, current_user: User) -> None:
    if current_user.role.name != "Admin" and not is_master_admin(current_user) and current_user.station_id != shift.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this shift")
