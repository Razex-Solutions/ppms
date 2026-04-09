from datetime import time

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.time import utc_now
from app.models.dispenser import Dispenser
from app.models.fuel_sale import FuelSale
from app.models.cash_submission import CashSubmission
from app.models.meter_adjustment_event import MeterAdjustmentEvent
from app.models.nozzle import Nozzle
from app.models.nozzle_reading import NozzleReading
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


def create_shift(db: Session, data: ShiftCreate, current_user: User) -> Shift:
    if not is_master_admin(current_user) and current_user.station_id != data.station_id:
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
    shift_cash = ensure_shift_cash(db, shift)

    shift.total_sales_cash = total_cash
    shift.total_sales_credit = total_credit
    shift.expected_cash = shift.initial_cash + total_cash
    shift.actual_cash_collected = data.actual_cash_collected
    shift.status = "closed"
    shift.end_time = utc_now()
    shift.notes = data.notes if data.notes else shift.notes
    shift_cash.cash_sales = total_cash
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
    submission_total = round(sum(submission.amount for submission in shift_cash.submissions), 2)

    shift.total_sales_cash = total_cash
    shift.total_sales_credit = total_credit
    shift.expected_cash = round((shift.initial_cash or 0.0) + total_cash, 2)
    shift_cash.cash_sales = total_cash
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
    submission = CashSubmission(
        shift_cash_id=shift_cash.id,
        amount=data.amount,
        submitted_by=current_user.id,
        notes=data.notes,
    )
    db.add(submission)
    db.flush()

    shift_cash.cash_submitted = (shift_cash.cash_submitted or 0.0) + data.amount
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


def build_station_opening_nozzle_groups(
    db: Session,
    station_id: int,
    *,
    shift: Shift | None = None,
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
    opening_snapshot_map = _get_shift_snapshot_map(db, shift, "shift_opening") if shift is not None else {}

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

        if provided.closing_meter < float(nozzle.meter_reading or 0.0):
            adjusted_after_shift_start = (
                db.query(MeterAdjustmentEvent)
                .filter(
                    MeterAdjustmentEvent.nozzle_id == nozzle.id,
                    MeterAdjustmentEvent.adjusted_at >= shift.start_time,
                )
                .order_by(MeterAdjustmentEvent.adjusted_at.desc(), MeterAdjustmentEvent.id.desc())
                .first()
            )
            if adjusted_after_shift_start is None or provided.closing_meter < float(nozzle.meter_reading or 0.0):
                issues.append(
                    ShiftCloseValidationIssueResponse(
                        code="abnormal_lower_meter",
                        title="Abnormal lower meter reading",
                        detail=f"Closing meter for nozzle {nozzle.name} is lower than the current meter without a valid adjustment path.",
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
    expected_cash = round(shift.expected_cash or 0.0, 2)
    if round(actual_cash_collected, 2) != expected_cash:
        issues.append(
            ShiftCloseValidationIssueResponse(
                code="cash_variance_detected",
                title="Cash variance detected",
                detail=f"Expected cash is {expected_cash} but actual cash entered is {round(actual_cash_collected, 2)}.",
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

    active_shift = (
        db.query(Shift)
        .filter(
            Shift.station_id == station_id,
            Shift.user_id == current_user.id,
            Shift.status == "open",
        )
        .order_by(Shift.start_time.desc(), Shift.id.desc())
        .first()
    )
    if active_shift:
        sync_shift_cash(db, active_shift)
        return CurrentShiftWorkspaceResponse(
            station_id=station_id,
            manager_user_id=current_user.id,
            shift_date=active_shift.start_time,
            status="open",
            message="Active shift is ready.",
            active_shift=_serialize_shift(active_shift),
            matched_template=_serialize_shift_template(active_shift.shift_template) if active_shift.shift_template else None,
            opening_cash_preview=active_shift.initial_cash,
            opening_nozzle_groups=build_station_opening_nozzle_groups(db, station_id, shift=active_shift),
            requires_manual_open=False,
        )

    matched_template = _find_matching_shift_template(db, station_id)
    opening_cash_preview = derive_shift_opening_cash(db, station_id)

    if matched_template is None:
        return CurrentShiftWorkspaceResponse(
            station_id=station_id,
            manager_user_id=current_user.id,
            shift_date=utc_now(),
            status="missing_template",
            message="No active shift template is configured for this station.",
            active_shift=None,
            matched_template=None,
            opening_cash_preview=opening_cash_preview,
            opening_nozzle_groups=build_station_opening_nozzle_groups(db, station_id),
            requires_manual_open=True,
        )

    return CurrentShiftWorkspaceResponse(
        station_id=station_id,
        manager_user_id=current_user.id,
        shift_date=utc_now(),
        status="prepared",
        message="A prepared shift template is available for the current time window.",
        active_shift=None,
        matched_template=_serialize_shift_template(matched_template),
        opening_cash_preview=opening_cash_preview,
        opening_nozzle_groups=build_station_opening_nozzle_groups(db, station_id),
        requires_manual_open=True,
    )
