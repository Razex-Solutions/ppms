from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models.meter_adjustment_event import MeterAdjustmentEvent
from app.models.nozzle import Nozzle
from app.models.user import User
from app.services.audit import log_audit_event
from app.services.notifications import get_station_watchers, notify_users
from app.services.station_modules import require_station_module_enabled


MODULE_NAME = "meter_adjustments"


def adjust_nozzle_meter(
    db: Session,
    *,
    nozzle: Nozzle,
    new_reading: float,
    reason: str,
    current_user: User,
) -> MeterAdjustmentEvent:
    if current_user.role.name != "Admin":
        raise HTTPException(status_code=403, detail="Only admin users can adjust nozzle meter readings")

    station_id = nozzle.dispenser.station_id
    require_station_module_enabled(db, station_id, MODULE_NAME)

    old_reading = nozzle.meter_reading or 0.0
    if new_reading == old_reading:
        raise HTTPException(status_code=400, detail="New meter reading must be different from the current reading")

    adjustment = MeterAdjustmentEvent(
        nozzle_id=nozzle.id,
        station_id=station_id,
        old_reading=old_reading,
        new_reading=new_reading,
        reason=reason.strip(),
        adjusted_by_user_id=current_user.id,
    )
    db.add(adjustment)
    nozzle.meter_reading = new_reading
    nozzle.current_segment_start_reading = new_reading
    nozzle.current_segment_started_at = utc_now()
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="nozzles",
        action="nozzles.adjust_meter",
        entity_type="meter_adjustment_event",
        entity_id=adjustment.id,
        station_id=station_id,
        details={
            "nozzle_id": nozzle.id,
            "old_reading": old_reading,
            "new_reading": new_reading,
            "reason": reason.strip(),
        },
    )
    notify_users(
        db,
        recipients=get_station_watchers(db, station_id, nozzle.dispenser.station.organization_id if nozzle.dispenser and nozzle.dispenser.station else None),
        actor_user=current_user,
        station_id=station_id,
        organization_id=nozzle.dispenser.station.organization_id if nozzle.dispenser and nozzle.dispenser.station else None,
        event_type="nozzle.meter_adjusted",
        title="Nozzle meter adjusted",
        message=f"{current_user.full_name} adjusted nozzle {nozzle.code} from {old_reading} to {new_reading}.",
        entity_type="meter_adjustment_event",
        entity_id=adjustment.id,
    )
    db.commit()
    db.refresh(adjustment)
    return adjustment
