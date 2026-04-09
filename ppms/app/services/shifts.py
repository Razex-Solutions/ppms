from datetime import time

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.time import utc_now
from app.models.customer_payment import CustomerPayment
from app.models.customer_credit_issue import CustomerCreditIssue
from app.models.dispenser import Dispenser
from app.models.expense import Expense
from app.models.fuel_sale import FuelSale
from app.models.fuel_price_history import FuelPriceHistory
from app.models.cash_submission import CashSubmission
from app.models.meter_adjustment_event import MeterAdjustmentEvent
from app.models.nozzle import Nozzle
from app.models.nozzle_reading import NozzleReading
from app.models.pos_sale import POSSale
from app.models.purchase import Purchase
from app.models.shift import Shift
from app.models.shift_cash import ShiftCash
from app.models.station import Station
from app.models.station_shift_template import StationShiftTemplate
from app.models.tank import Tank
from app.models.tank_dip import TankDip
from app.models.user import User
from app.schemas.shift import (
    CurrentShiftDispenserGroupResponse,
    CurrentShiftNozzleOpeningResponse,
    ShiftRateChangeAlertResponse,
    ShiftRateChangeBoundaryCapture,
    ShiftCloseValidationIssueResponse,
    ShiftCloseValidationResponse,
    CurrentShiftWorkspaceResponse,
    ShiftCreate,
    ShiftCloseNozzleReading,
    ShiftTemplateSummaryResponse,
    ShiftUpdate,
)
from app.schemas.shift_cash import CashSubmissionCreate
from app.services.audit import log_audit_event
from app.services.notifications import notify_station_low_usage_dip_skip


def get_latest_station_closed_shift(db: Session, station_id: int) -> Shift | None:
    return (
        db.query(Shift)
        .filter(
            Shift.station_id == station_id,
            Shift.status == "closed",
        )
        .order_by(Shift.end_time.desc(), Shift.id.desc())
        .first()
    )


def get_station_open_shift(db: Session, station_id: int) -> Shift | None:
    return (
        db.query(Shift)
        .filter(
            Shift.station_id == station_id,
            Shift.status == "open",
        )
        .order_by(Shift.start_time.desc(), Shift.id.desc())
        .first()
    )


def derive_shift_opening_cash(db: Session, station_id: int) -> float:
    latest_closed_shift = get_latest_station_closed_shift(db, station_id)
    if latest_closed_shift is None:
        return 0.0

    shift_cash = ensure_shift_cash(db, latest_closed_shift)
    if shift_cash.closing_cash is not None:
        return max(round(shift_cash.closing_cash, 2), 0.0)
    cash_in_hand = round((shift_cash.expected_cash or 0.0) - (shift_cash.cash_submitted or 0.0), 2)
    if cash_in_hand < 0:
        return 0.0
    return cash_in_hand


def _get_shift_window_end(shift: Shift):
    return shift.end_time or utc_now()


def _get_shift_opening_snapshot_map(db: Session, shift: Shift) -> dict[int, float]:
    return _get_shift_snapshot_map(db, shift, "shift_opening")


def _get_shift_nozzle_adjustments(
    db: Session,
    *,
    shift: Shift,
    nozzle_id: int,
) -> list[MeterAdjustmentEvent]:
    return (
        db.query(MeterAdjustmentEvent)
        .filter(
            MeterAdjustmentEvent.nozzle_id == nozzle_id,
            MeterAdjustmentEvent.adjusted_at >= shift.start_time,
            MeterAdjustmentEvent.adjusted_at <= _get_shift_window_end(shift),
        )
        .order_by(MeterAdjustmentEvent.adjusted_at.asc(), MeterAdjustmentEvent.id.asc())
        .all()
    )


def calculate_shift_nozzle_reconciled_liters(
    db: Session,
    *,
    shift: Shift,
    nozzle: Nozzle,
    closing_meter: float,
    opening_snapshot_map: dict[int, float] | None = None,
) -> dict[str, object]:
    opening_snapshot_map = opening_snapshot_map or _get_shift_opening_snapshot_map(db, shift)
    opening_meter = float(opening_snapshot_map.get(nozzle.id, nozzle.meter_reading or 0.0))
    adjustments = _get_shift_nozzle_adjustments(db, shift=shift, nozzle_id=nozzle.id)

    segment_start = opening_meter
    total_liters = 0.0
    segments: list[dict[str, float | int | str]] = []
    invalid_reason: str | None = None

    for adjustment in adjustments:
        segment_end = float(adjustment.old_reading)
        if segment_end < segment_start:
            invalid_reason = (
                f"Adjustment path is invalid for nozzle {nozzle.name}: "
                f"segment end {segment_end} is lower than segment start {segment_start}."
            )
            break
        segment_liters = round(segment_end - segment_start, 2)
        total_liters = round(total_liters + segment_liters, 2)
        segments.append(
            {
                "type": "pre_adjustment",
                "adjustment_event_id": adjustment.id,
                "start_meter": segment_start,
                "end_meter": segment_end,
                "liters": segment_liters,
            }
        )
        segment_start = float(adjustment.new_reading)

    if invalid_reason is None:
        if float(closing_meter) < segment_start:
            invalid_reason = (
                f"Closing meter {float(closing_meter)} is lower than the last valid segment start "
                f"{segment_start} for nozzle {nozzle.name}."
            )
        else:
            final_segment_liters = round(float(closing_meter) - segment_start, 2)
            total_liters = round(total_liters + final_segment_liters, 2)
            segments.append(
                {
                    "type": "post_adjustment" if adjustments else "continuous",
                    "adjustment_event_id": adjustments[-1].id if adjustments else 0,
                    "start_meter": segment_start,
                    "end_meter": float(closing_meter),
                    "liters": final_segment_liters,
                }
            )

    return {
        "opening_meter": opening_meter,
        "total_liters": round(total_liters, 2),
        "has_adjustment": bool(adjustments),
        "adjustment_count": len(adjustments),
        "segments": segments,
        "invalid_reason": invalid_reason,
        "last_segment_start": segment_start,
    }


def _get_shift_rate_change_alerts(
    db: Session,
    *,
    shift: Shift,
    station_id: int,
) -> list[ShiftRateChangeAlertResponse]:
    change_events = (
        db.query(FuelPriceHistory)
        .filter(
            FuelPriceHistory.station_id == station_id,
            FuelPriceHistory.effective_at >= shift.start_time,
            FuelPriceHistory.effective_at <= _get_shift_window_end(shift),
        )
        .order_by(FuelPriceHistory.effective_at.asc(), FuelPriceHistory.id.asc())
        .all()
    )
    if not change_events:
        return []

    nozzles = (
        db.query(Nozzle)
        .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
        .filter(
            Dispenser.station_id == station_id,
            Dispenser.is_active.is_(True),
            Nozzle.is_active.is_(True),
        )
        .all()
    )
    alerts: list[ShiftRateChangeAlertResponse] = []
    for event in change_events:
        affected_nozzle_ids = sorted(
            nozzle.id for nozzle in nozzles if nozzle.fuel_type_id == event.fuel_type_id
        )
        if not affected_nozzle_ids:
            continue
        recorded_nozzle_ids = sorted(
            nozzle_id
            for (nozzle_id,) in (
                db.query(NozzleReading.nozzle_id)
                .filter(
                    NozzleReading.shift_id == shift.id,
                    NozzleReading.reading_type == "rate_change_boundary",
                    NozzleReading.nozzle_id.in_(affected_nozzle_ids),
                    NozzleReading.created_at >= event.effective_at,
                )
                .distinct()
                .all()
            )
        )
        alerts.append(
            ShiftRateChangeAlertResponse(
                fuel_type_id=event.fuel_type_id,
                fuel_type_name=event.fuel_type.name if event.fuel_type else None,
                effective_at=event.effective_at,
                affected_nozzle_ids=affected_nozzle_ids,
                recorded_nozzle_ids=recorded_nozzle_ids,
                message=(
                    f"Rate changed for {event.fuel_type.name if event.fuel_type else 'fuel'} during this shift. "
                    "Affected nozzles need a boundary meter reading."
                ),
            )
        )
    return alerts


def calculate_shift_cash_breakdown(
    db: Session,
    shift: Shift,
) -> dict[str, float]:
    window_end = _get_shift_window_end(shift)

    fuel_cash_sales = round(
        sum(
            sale.total_amount
            for sale in db.query(FuelSale).filter(
                FuelSale.shift_id == shift.id,
                FuelSale.sale_type == "cash",
                FuelSale.is_reversed.is_(False),
            ).all()
        ),
        2,
    )

    lubricant_cash_sales = round(
        sum(
            sale.total_amount
            for sale in db.query(POSSale).filter(
                POSSale.station_id == shift.station_id,
                POSSale.created_at >= shift.start_time,
                POSSale.created_at <= window_end,
                POSSale.payment_method == "cash",
                POSSale.is_reversed.is_(False),
            ).all()
        ),
        2,
    )

    credit_recoveries = round(
        sum(
            payment.amount
            for payment in db.query(CustomerPayment).filter(
                CustomerPayment.station_id == shift.station_id,
                CustomerPayment.created_at >= shift.start_time,
                CustomerPayment.created_at <= window_end,
                CustomerPayment.payment_method == "cash",
                CustomerPayment.is_reversed.is_(False),
            ).all()
        ),
        2,
    )

    credit_given = round(
        sum(
            credit_issue.amount
            for credit_issue in db.query(CustomerCreditIssue).filter(
                CustomerCreditIssue.station_id == shift.station_id,
                CustomerCreditIssue.created_at >= shift.start_time,
                CustomerCreditIssue.created_at <= window_end,
            ).all()
        ),
        2,
    )

    cash_expenses = round(
        sum(
            expense.amount
            for expense in db.query(Expense).filter(
                Expense.station_id == shift.station_id,
                Expense.created_at >= shift.start_time,
                Expense.created_at <= window_end,
                Expense.status != "rejected",
            ).all()
        ),
        2,
    )

    accountable_cash = round(
        (shift.initial_cash or 0.0)
        + fuel_cash_sales
        + lubricant_cash_sales
        + credit_recoveries
        - cash_expenses,
        2,
    )

    return {
        "fuel_cash_sales": fuel_cash_sales,
        "lubricant_cash_sales": lubricant_cash_sales,
        "credit_recoveries": credit_recoveries,
        "credit_given": credit_given,
        "cash_expenses": cash_expenses,
        "accountable_cash": accountable_cash,
    }


def create_shift(db: Session, data: ShiftCreate, current_user: User) -> Shift:
    if not is_master_admin(current_user) and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    existing_station_shift = get_station_open_shift(db, data.station_id)
    if existing_station_shift is not None:
        if existing_station_shift.user_id == current_user.id:
            raise HTTPException(
                status_code=400,
                detail=f"You already have an open shift (ID: {existing_station_shift.id}) at this station",
            )
        active_manager_name = (
            existing_station_shift.user.full_name
            if existing_station_shift.user and existing_station_shift.user.full_name
            else f"Manager {existing_station_shift.user_id}"
        )
        raise HTTPException(
            status_code=400,
            detail=f"Shift handover is pending. {active_manager_name} still has an open shift at this station.",
        )

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

    opening_cash = derive_shift_opening_cash(db, data.station_id)
    shift = Shift(
        station_id=data.station_id,
        user_id=current_user.id,
        shift_template_id=shift_template.id if shift_template else None,
        shift_name=shift_template.name if shift_template else None,
        initial_cash=opening_cash,
        expected_cash=opening_cash,
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
        opening_cash=opening_cash,
        expected_cash=opening_cash,
        notes=shift.notes,
    )
    db.add(shift_cash)
    db.flush()
    record_shift_opening_snapshots(db, shift)
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
            "requested_initial_cash": data.initial_cash,
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

    validation = validate_shift_close(db, shift=shift, actual_cash_collected=data.actual_cash_collected, nozzle_readings=data.nozzle_readings)
    if not validation.can_close:
        raise HTTPException(
            status_code=400,
            detail={
                "message": "Shift close validation failed",
                "blocking_issue_count": validation.blocking_issue_count,
                "issues": [issue.model_dump() for issue in validation.issues if issue.blocking],
            },
        )

    low_usage_dip_warnings = [
        issue for issue in validation.issues if issue.code == "dip_skipped_low_usage" and issue.tank_id is not None
    ]

    record_shift_closing_snapshots(db, shift=shift, nozzle_readings=data.nozzle_readings)
    sales = db.query(FuelSale).filter(
        FuelSale.shift_id == shift.id,
        FuelSale.is_reversed.is_(False),
    ).all()
    total_cash = sum(s.total_amount for s in sales if s.sale_type == "cash")
    total_credit = sum(s.total_amount for s in sales if s.sale_type == "credit")
    cash_breakdown = calculate_shift_cash_breakdown(
        db,
        shift,
    )
    shift_cash = ensure_shift_cash(db, shift)

    shift.total_sales_cash = round(total_cash, 2)
    shift.total_sales_credit = round(total_credit + cash_breakdown["credit_given"], 2)
    shift.expected_cash = cash_breakdown["accountable_cash"]
    shift.actual_cash_collected = data.actual_cash_collected
    shift.status = "closed"
    shift.end_time = utc_now()
    shift.notes = data.notes if data.notes else shift.notes
    shift_cash.cash_sales = cash_breakdown["fuel_cash_sales"]
    shift_cash.expected_cash = shift.expected_cash
    submission_total = sum(submission.amount for submission in shift_cash.submissions)
    shift_cash.cash_submitted = submission_total
    shift_cash.closing_cash = data.actual_cash_collected
    accountable_cash = round((shift_cash.cash_submitted or 0.0) + (shift_cash.closing_cash or 0.0), 2)
    shift_cash.difference = round(accountable_cash - shift.expected_cash, 2)
    shift.difference = shift_cash.difference
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
            "closing_cash": shift.actual_cash_collected,
            "cash_submitted": shift_cash.cash_submitted,
            "lubricant_cash_sales": cash_breakdown["lubricant_cash_sales"],
            "credit_recoveries": cash_breakdown["credit_recoveries"],
            "credit_given": cash_breakdown["credit_given"],
            "cash_expenses": cash_breakdown["cash_expenses"],
            "difference": shift.difference,
        },
    )
    for issue in low_usage_dip_warnings:
        notify_station_low_usage_dip_skip(
            db,
            actor_user=current_user,
            station_id=shift.station_id,
            organization_id=shift.station.organization_id if shift.station else None,
            tank_id=issue.tank_id,
            usage_liters=issue.usage_liters or 0.0,
        )
    db.commit()
    db.refresh(shift)
    return shift


def sync_shift_cash(db: Session, shift: Shift) -> ShiftCash:
    shift_cash = ensure_shift_cash(db, shift)
    sales = db.query(FuelSale).filter(
        FuelSale.shift_id == shift.id,
        FuelSale.is_reversed.is_(False),
    ).all()
    total_cash = round(sum(s.total_amount for s in sales if s.sale_type == "cash"), 2)
    total_credit = round(sum(s.total_amount for s in sales if s.sale_type == "credit"), 2)
    cash_breakdown = calculate_shift_cash_breakdown(db, shift)
    submission_total = round(sum(submission.amount for submission in shift_cash.submissions), 2)

    shift.total_sales_cash = total_cash
    shift.total_sales_credit = total_credit
    shift.expected_cash = cash_breakdown["accountable_cash"]
    shift_cash.cash_sales = cash_breakdown["fuel_cash_sales"]
    shift_cash.expected_cash = shift.expected_cash
    shift_cash.cash_submitted = submission_total
    if shift.status == "closed" and shift.actual_cash_collected is not None:
        shift_cash.closing_cash = shift.actual_cash_collected
        shift_cash.difference = round(
            (shift_cash.cash_submitted or 0.0) + (shift_cash.closing_cash or 0.0) - shift.expected_cash,
            2,
        )
        shift.difference = shift_cash.difference
    else:
        shift_cash.difference = round(shift.expected_cash - submission_total, 2)
    db.flush()
    return shift_cash


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
    sync_shift_cash(db, shift)
    available_cash = round((shift.expected_cash or 0.0) - (shift_cash.cash_submitted or 0.0), 2)
    if data.amount > available_cash:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot submit {round(data.amount, 2)}. Only {round(available_cash, 2)} is currently accountable in hand for this shift.",
        )
    submission = CashSubmission(
        shift_cash_id=shift_cash.id,
        amount=data.amount,
        submitted_by=current_user.id,
        notes=data.notes,
    )
    db.add(submission)
    db.flush()
    sync_shift_cash(db, shift)

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
    if not is_master_admin(current_user) and current_user.station_id != shift.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this shift")


def _format_window_label(start_time: time, end_time: time) -> str:
    start_label = start_time.strftime("%H:%M")
    end_label = end_time.strftime("%H:%M")
    if start_time == end_time:
        return f"{start_label} - {end_label} (24h)"
    return f"{start_label} - {end_label}"


def _serialize_shift_template(template: StationShiftTemplate) -> ShiftTemplateSummaryResponse:
    return ShiftTemplateSummaryResponse(
        id=template.id,
        station_id=template.station_id,
        name=template.name,
        start_time=template.start_time,
        end_time=template.end_time,
        is_active=template.is_active,
        covers_full_day=template.start_time == template.end_time,
        window_label=_format_window_label(template.start_time, template.end_time),
    )


def _serialize_shift(shift: Shift) -> dict[str, object | None]:
    return {
        "id": shift.id,
        "station_id": shift.station_id,
        "user_id": shift.user_id,
        "shift_template_id": shift.shift_template_id,
        "shift_name": shift.shift_name,
        "start_time": shift.start_time,
        "end_time": shift.end_time,
        "status": shift.status,
        "initial_cash": shift.initial_cash,
        "total_sales_cash": shift.total_sales_cash,
        "total_sales_credit": shift.total_sales_credit,
        "expected_cash": shift.expected_cash,
        "actual_cash_collected": shift.actual_cash_collected,
        "difference": shift.difference,
        "notes": shift.notes,
    }


def _get_shift_snapshot_map(db: Session, shift: Shift, reading_type: str) -> dict[int, float]:
    readings = (
        db.query(NozzleReading)
        .filter(
            NozzleReading.shift_id == shift.id,
            NozzleReading.reading_type == reading_type,
        )
        .order_by(NozzleReading.created_at.asc(), NozzleReading.id.asc())
        .all()
    )
    return {reading.nozzle_id: float(reading.reading) for reading in readings}


def record_shift_opening_snapshots(db: Session, shift: Shift) -> None:
    existing_snapshot_ids = {
        nozzle_id
        for (nozzle_id,) in (
            db.query(NozzleReading.nozzle_id)
            .filter(
                NozzleReading.shift_id == shift.id,
                NozzleReading.reading_type == "shift_opening",
            )
            .all()
        )
    }
    nozzles = (
        db.query(Nozzle)
        .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
        .filter(
            Dispenser.station_id == shift.station_id,
            Dispenser.is_active.is_(True),
            Nozzle.is_active.is_(True),
        )
        .order_by(Dispenser.id.asc(), Nozzle.id.asc())
        .all()
    )
    for nozzle in nozzles:
        if nozzle.id in existing_snapshot_ids:
            continue
        db.add(
            NozzleReading(
                nozzle_id=nozzle.id,
                reading=float(nozzle.meter_reading or 0.0),
                shift_id=shift.id,
                reading_type="shift_opening",
            )
        )
    db.flush()


def record_shift_closing_snapshots(
    db: Session,
    *,
    shift: Shift,
    nozzle_readings: list[ShiftCloseNozzleReading],
) -> None:
    closing_by_nozzle_id = {item.nozzle_id: float(item.closing_meter) for item in nozzle_readings}
    nozzles = (
        db.query(Nozzle)
        .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
        .filter(
            Dispenser.station_id == shift.station_id,
            Dispenser.is_active.is_(True),
            Nozzle.is_active.is_(True),
        )
        .all()
    )
    nozzle_by_id = {nozzle.id: nozzle for nozzle in nozzles}
    existing = (
        db.query(NozzleReading)
        .filter(
            NozzleReading.shift_id == shift.id,
            NozzleReading.reading_type == "shift_closing",
        )
        .all()
    )
    existing_by_nozzle_id = {reading.nozzle_id: reading for reading in existing}
    for nozzle_id, closing_meter in closing_by_nozzle_id.items():
        nozzle = nozzle_by_id.get(nozzle_id)
        if nozzle is not None:
            nozzle.meter_reading = closing_meter
        existing_reading = existing_by_nozzle_id.get(nozzle_id)
        if existing_reading is not None:
            existing_reading.reading = closing_meter
            continue
        db.add(
            NozzleReading(
                nozzle_id=nozzle_id,
                reading=closing_meter,
                shift_id=shift.id,
                reading_type="shift_closing",
            )
        )
    db.flush()


def capture_rate_change_boundary_readings(
    db: Session,
    *,
    shift: Shift,
    nozzle_readings: list[ShiftCloseNozzleReading],
    current_user: User,
) -> Shift:
    if shift.status != "open":
        raise HTTPException(status_code=400, detail="Rate-change boundary readings can only be captured on an open shift")

    rate_change_alerts = _get_shift_rate_change_alerts(db, shift=shift, station_id=shift.station_id)
    if not rate_change_alerts:
        raise HTTPException(status_code=400, detail="No active rate-change boundary reading is required for this shift")

    station_nozzles = (
        db.query(Nozzle)
        .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
        .filter(
            Dispenser.station_id == shift.station_id,
            Dispenser.is_active.is_(True),
            Nozzle.is_active.is_(True),
        )
        .all()
    )
    nozzle_by_id = {nozzle.id: nozzle for nozzle in station_nozzles}
    provided_by_id = {item.nozzle_id: float(item.closing_meter) for item in nozzle_readings}
    required_nozzle_ids = {nozzle_id for alert in rate_change_alerts for nozzle_id in alert.affected_nozzle_ids}

    for nozzle_id in required_nozzle_ids:
        if nozzle_id not in provided_by_id:
            continue
        nozzle = nozzle_by_id.get(nozzle_id)
        if nozzle is None:
            continue
        boundary_meter = provided_by_id[nozzle_id]
        if boundary_meter < float(nozzle.meter_reading or 0.0):
            raise HTTPException(status_code=400, detail=f"Boundary meter for nozzle {nozzle.name} cannot be lower than the current meter")
        db.add(
            NozzleReading(
                nozzle_id=nozzle_id,
                reading=boundary_meter,
                shift_id=shift.id,
                reading_type="rate_change_boundary",
            )
        )

    log_audit_event(
        db,
        current_user=current_user,
        module="shifts",
        action="shifts.capture_rate_change_boundary",
        entity_type="shift",
        entity_id=shift.id,
        station_id=shift.station_id,
        details={
            "nozzle_count": len([nozzle_id for nozzle_id in provided_by_id if nozzle_id in required_nozzle_ids]),
        },
    )
    db.commit()
    db.refresh(shift)
    return shift


def build_station_opening_nozzle_groups(
    db: Session,
    station_id: int,
    *,
    shift: Shift | None = None,
    snapshot_type: str = "shift_opening",
) -> list[CurrentShiftDispenserGroupResponse]:
    dispensers = (
        db.query(Dispenser)
        .filter(
            Dispenser.station_id == station_id,
            Dispenser.is_active.is_(True),
        )
        .order_by(Dispenser.id.asc())
        .all()
    )
    if not dispensers:
        return []

    nozzles = (
        db.query(Nozzle)
        .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
        .filter(
            Dispenser.station_id == station_id,
            Dispenser.is_active.is_(True),
            Nozzle.is_active.is_(True),
        )
        .order_by(Dispenser.id.asc(), Nozzle.id.asc())
        .all()
    )
    adjustment_nozzle_ids = {
        nozzle_id
        for (nozzle_id,) in (
            db.query(MeterAdjustmentEvent.nozzle_id)
            .join(Nozzle, Nozzle.id == MeterAdjustmentEvent.nozzle_id)
            .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
            .filter(Dispenser.station_id == station_id)
            .distinct()
            .all()
        )
    }
    opening_snapshot_map = _get_shift_snapshot_map(db, shift, snapshot_type) if shift is not None else {}
    rate_change_required_nozzle_ids: set[int] = set()
    rate_change_recorded_nozzle_ids: set[int] = set()
    if shift is not None:
        for alert in _get_shift_rate_change_alerts(db, shift=shift, station_id=station_id):
            rate_change_required_nozzle_ids.update(alert.affected_nozzle_ids)
            rate_change_recorded_nozzle_ids.update(alert.recorded_nozzle_ids)

    grouped: dict[int, list[CurrentShiftNozzleOpeningResponse]] = {}
    for nozzle in nozzles:
        opening_meter = opening_snapshot_map.get(nozzle.id, float(nozzle.meter_reading or 0.0))
        grouped.setdefault(nozzle.dispenser_id, []).append(
            CurrentShiftNozzleOpeningResponse(
                nozzle_id=nozzle.id,
                nozzle_name=nozzle.name,
                nozzle_code=nozzle.code,
                dispenser_id=nozzle.dispenser_id,
                dispenser_name=nozzle.dispenser.name if nozzle.dispenser else f"Dispenser {nozzle.dispenser_id}",
                fuel_type_id=nozzle.fuel_type_id,
                fuel_type_name=nozzle.fuel_type.name if nozzle.fuel_type else None,
                tank_id=nozzle.tank_id,
                tank_name=nozzle.tank.name if nozzle.tank else None,
                opening_meter=opening_meter,
                current_meter=float(nozzle.meter_reading or 0.0),
                has_meter_adjustment_history=nozzle.id in adjustment_nozzle_ids,
                requires_rate_change_boundary=nozzle.id in rate_change_required_nozzle_ids,
                rate_change_boundary_recorded=nozzle.id in rate_change_recorded_nozzle_ids,
            )
        )

    return [
        CurrentShiftDispenserGroupResponse(
            dispenser_id=dispenser.id,
            dispenser_name=dispenser.name,
            dispenser_code=dispenser.code,
            nozzles=grouped.get(dispenser.id, []),
        )
        for dispenser in dispensers
    ]


def validate_shift_close(
    db: Session,
    *,
    shift: Shift,
    actual_cash_collected: float,
    nozzle_readings: list[ShiftCloseNozzleReading],
) -> ShiftCloseValidationResponse:
    issues: list[ShiftCloseValidationIssueResponse] = []
    nozzle_readings_by_id = {item.nozzle_id: item for item in nozzle_readings}
    opening_snapshot_map = _get_shift_opening_snapshot_map(db, shift)

    station_nozzles = (
        db.query(Nozzle)
        .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
        .filter(
            Dispenser.station_id == shift.station_id,
            Dispenser.is_active.is_(True),
            Nozzle.is_active.is_(True),
        )
        .order_by(Dispenser.id.asc(), Nozzle.id.asc())
        .all()
    )

    for nozzle in station_nozzles:
        provided = nozzle_readings_by_id.get(nozzle.id)
        if provided is None:
            issues.append(
                ShiftCloseValidationIssueResponse(
                    code="missing_nozzle_reading",
                    title="Missing nozzle reading",
                    detail=f"Closing meter is missing for nozzle {nozzle.name}.",
                    blocking=True,
                    nozzle_id=nozzle.id,
                    tank_id=nozzle.tank_id,
                )
            )
            continue

        reconciled = calculate_shift_nozzle_reconciled_liters(
            db,
            shift=shift,
            nozzle=nozzle,
            closing_meter=float(provided.closing_meter),
            opening_snapshot_map=opening_snapshot_map,
        )
        invalid_reason = reconciled["invalid_reason"]
        if invalid_reason is not None:
            issues.append(
                ShiftCloseValidationIssueResponse(
                    code="abnormal_lower_meter",
                    title="Abnormal lower meter reading",
                    detail=invalid_reason,
                    blocking=True,
                    nozzle_id=nozzle.id,
                    tank_id=nozzle.tank_id,
                )
            )

    for alert in _get_shift_rate_change_alerts(db, shift=shift, station_id=shift.station_id):
        missing_nozzle_ids = sorted(set(alert.affected_nozzle_ids) - set(alert.recorded_nozzle_ids))
        for nozzle_id in missing_nozzle_ids:
            nozzle = next((item for item in station_nozzles if item.id == nozzle_id), None)
            issues.append(
                ShiftCloseValidationIssueResponse(
                    code="missing_rate_change_boundary",
                    title="Missing rate-change boundary reading",
                    detail=(
                        f"No boundary meter reading was captured for nozzle {nozzle.name if nozzle else nozzle_id} "
                        f"after the mid-shift rate change for {alert.fuel_type_name or 'fuel'}."
                    ),
                    blocking=True,
                    nozzle_id=nozzle_id,
                    tank_id=nozzle.tank_id if nozzle else None,
                )
            )

    shift_credit_issues = (
        db.query(CustomerCreditIssue)
        .filter(CustomerCreditIssue.shift_id == shift.id)
        .all()
    )
    credit_quantity_by_nozzle: dict[int, float] = {}
    for issue in shift_credit_issues:
        if issue.nozzle_id is None or issue.quantity is None:
            continue
        credit_quantity_by_nozzle[issue.nozzle_id] = round(
            credit_quantity_by_nozzle.get(issue.nozzle_id, 0.0) + float(issue.quantity or 0.0),
            2,
        )

    for nozzle in station_nozzles:
        provided = nozzle_readings_by_id.get(nozzle.id)
        if provided is None:
            continue
        reconciled = calculate_shift_nozzle_reconciled_liters(
            db,
            shift=shift,
            nozzle=nozzle,
            closing_meter=float(provided.closing_meter),
            opening_snapshot_map=opening_snapshot_map,
        )
        sold_quantity = round(float(reconciled["total_liters"]), 2)
        credit_quantity = round(credit_quantity_by_nozzle.get(nozzle.id, 0.0), 2)
        if credit_quantity > sold_quantity:
            issues.append(
                ShiftCloseValidationIssueResponse(
                    code="credit_exceeds_nozzle_sales",
                    title="Credit exceeds nozzle sales",
                    detail=(
                        f"Credit recorded for nozzle {nozzle.name} is {credit_quantity} liters "
                        f"but the closing meter only supports {sold_quantity} liters."
                    ),
                    blocking=True,
                    nozzle_id=nozzle.id,
                    tank_id=nozzle.tank_id,
                )
            )

    shift_end_reference = shift.end_time or utc_now()
    active_tank_ids: set[int] = set()
    tank_usage: dict[int, float] = {}

    shift_sales = (
        db.query(FuelSale)
        .filter(
            FuelSale.shift_id == shift.id,
            FuelSale.is_reversed.is_(False),
        )
        .all()
    )
    for sale in shift_sales:
        nozzle = next((item for item in station_nozzles if item.id == sale.nozzle_id), None)
        if nozzle is None:
            continue
        active_tank_ids.add(nozzle.tank_id)
        tank_usage[nozzle.tank_id] = round(tank_usage.get(nozzle.tank_id, 0.0) + float(sale.quantity or 0.0), 2)

    purchases = (
        db.query(Purchase)
        .join(Tank, Tank.id == Purchase.tank_id)
        .filter(
            Tank.station_id == shift.station_id,
            Purchase.created_at >= shift.start_time,
            Purchase.created_at <= shift_end_reference,
            Purchase.is_reversed.is_(False),
        )
        .all()
    )
    for purchase in purchases:
        active_tank_ids.add(purchase.tank_id)

    for tank_id in sorted(active_tank_ids):
        latest_shift_dip = (
            db.query(TankDip)
            .filter(
                TankDip.tank_id == tank_id,
                TankDip.created_at >= shift.start_time,
                TankDip.created_at <= shift_end_reference,
            )
            .order_by(TankDip.created_at.desc(), TankDip.id.desc())
            .first()
        )
        if latest_shift_dip is not None:
            continue

        usage = tank_usage.get(tank_id, 0.0)
        if usage < 100:
            issues.append(
                ShiftCloseValidationIssueResponse(
                    code="dip_skipped_low_usage",
                    title="Dip skipped due to low usage",
                    detail=f"Tank {tank_id} had usage below 100 and no dip was recorded. Admin review is still recommended.",
                    blocking=False,
                    tank_id=tank_id,
                    usage_liters=usage,
                )
            )
            continue

        issues.append(
            ShiftCloseValidationIssueResponse(
                code="missing_required_dip",
                title="Missing required dip",
                detail=f"Tank {tank_id} was active during the shift but has no dip recorded for the shift window.",
                blocking=True,
                tank_id=tank_id,
            )
        )

    sync_shift_cash(db, shift)
    cash_breakdown = calculate_shift_cash_breakdown(
        db,
        shift,
    )
    accountable_cash = round(cash_breakdown["accountable_cash"] or 0.0, 2)
    submission_total = round(sum(submission.amount for submission in shift.shift_cash.submissions), 2) if shift.shift_cash else 0.0
    accountable_total = round(submission_total + actual_cash_collected, 2)
    if accountable_total != accountable_cash:
        issues.append(
            ShiftCloseValidationIssueResponse(
                code="cash_variance_detected",
                title="Cash variance detected",
                detail=(
                    f"Accountable cash is {accountable_cash} but submissions plus closing cash "
                    f"equal {accountable_total}."
                ),
                blocking=False,
            )
        )

    blocking_issue_count = sum(1 for issue in issues if issue.blocking)
    warning_count = len(issues) - blocking_issue_count
    return ShiftCloseValidationResponse(
        shift_id=shift.id,
        can_close=blocking_issue_count == 0,
        blocking_issue_count=blocking_issue_count,
        warning_count=warning_count,
        issues=issues,
    )


def _find_matching_shift_template(db: Session, station_id: int) -> StationShiftTemplate | None:
    templates = (
        db.query(StationShiftTemplate)
        .filter(
            StationShiftTemplate.station_id == station_id,
            StationShiftTemplate.is_active.is_(True),
        )
        .order_by(StationShiftTemplate.start_time.asc(), StationShiftTemplate.id.asc())
        .all()
    )
    if not templates:
        return None

    current_time = utc_now().time()
    for template in templates:
        start_time = template.start_time
        end_time = template.end_time
        if start_time == end_time:
            return template
        if start_time < end_time:
            if start_time <= current_time < end_time:
                return template
        else:
            if current_time >= start_time or current_time < end_time:
                return template
    return templates[0]


def get_current_shift_workspace(db: Session, *, station_id: int, current_user: User) -> CurrentShiftWorkspaceResponse:
    if not is_master_admin(current_user) and current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    active_shift = get_station_open_shift(db, station_id)
    if active_shift:
        active_manager_name = (
            active_shift.user.full_name
            if active_shift.user and active_shift.user.full_name
            else f"Manager {active_shift.user_id}"
        )
        rate_change_alerts = _get_shift_rate_change_alerts(db, shift=active_shift, station_id=station_id)
        if active_shift.user_id != current_user.id:
            return CurrentShiftWorkspaceResponse(
                station_id=station_id,
                manager_user_id=current_user.id,
                active_manager_user_id=active_shift.user_id,
                active_manager_name=active_manager_name,
                shift_date=active_shift.start_time,
                status="occupied",
                message=f"{active_manager_name} is currently handling this station shift. The next manager can start only after shift handover/close.",
                active_shift=None,
                matched_template=_serialize_shift_template(active_shift.shift_template) if active_shift.shift_template else None,
                opening_cash_preview=active_shift.initial_cash,
                opening_nozzle_groups=build_station_opening_nozzle_groups(db, station_id, shift=active_shift),
                rate_change_alerts=rate_change_alerts,
                requires_manual_open=False,
            )
        sync_shift_cash(db, active_shift)
        return CurrentShiftWorkspaceResponse(
            station_id=station_id,
            manager_user_id=current_user.id,
            active_manager_user_id=active_shift.user_id,
            active_manager_name=active_manager_name,
            shift_date=active_shift.start_time,
            status="open",
            message="Active shift is ready.",
            active_shift=_serialize_shift(active_shift),
            matched_template=_serialize_shift_template(active_shift.shift_template) if active_shift.shift_template else None,
            opening_cash_preview=active_shift.initial_cash,
            opening_nozzle_groups=build_station_opening_nozzle_groups(db, station_id, shift=active_shift),
            rate_change_alerts=rate_change_alerts,
            requires_manual_open=False,
        )

    matched_template = _find_matching_shift_template(db, station_id)
    opening_cash_preview = derive_shift_opening_cash(db, station_id)
    latest_closed_shift = get_latest_station_closed_shift(db, station_id)

    if matched_template is None:
        return CurrentShiftWorkspaceResponse(
            station_id=station_id,
            manager_user_id=current_user.id,
            active_manager_user_id=None,
            active_manager_name=None,
            shift_date=utc_now(),
            status="missing_template",
            message="No active shift template is configured for this station.",
            active_shift=None,
            matched_template=None,
            opening_cash_preview=opening_cash_preview,
            opening_nozzle_groups=build_station_opening_nozzle_groups(
                db,
                station_id,
                shift=latest_closed_shift,
                snapshot_type="shift_closing",
            ),
            rate_change_alerts=[],
            requires_manual_open=True,
        )

    return CurrentShiftWorkspaceResponse(
        station_id=station_id,
        manager_user_id=current_user.id,
        active_manager_user_id=None,
        active_manager_name=None,
        shift_date=utc_now(),
        status="prepared",
        message="A prepared shift is ready for the next manager handover at this station.",
        active_shift=None,
        matched_template=_serialize_shift_template(matched_template),
        opening_cash_preview=opening_cash_preview,
        opening_nozzle_groups=build_station_opening_nozzle_groups(
            db,
            station_id,
            shift=latest_closed_shift,
            snapshot_type="shift_closing",
        ),
        rate_change_alerts=[],
        requires_manual_open=True,
    )
