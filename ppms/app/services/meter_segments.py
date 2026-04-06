from datetime import datetime

from sqlalchemy.orm import Session

from app.models.fuel_sale import FuelSale
from app.models.meter_adjustment_event import MeterAdjustmentEvent
from app.models.nozzle import Nozzle


def build_nozzle_meter_segments(db: Session, nozzle: Nozzle) -> list[dict[str, object | None]]:
    sales = (
        db.query(FuelSale)
        .filter(
            FuelSale.nozzle_id == nozzle.id,
            FuelSale.is_reversed.is_(False),
        )
        .order_by(FuelSale.created_at.asc(), FuelSale.id.asc())
        .all()
    )
    adjustments = (
        db.query(MeterAdjustmentEvent)
        .filter(MeterAdjustmentEvent.nozzle_id == nozzle.id)
        .order_by(MeterAdjustmentEvent.adjusted_at.asc(), MeterAdjustmentEvent.id.asc())
        .all()
    )

    events: list[tuple[str, datetime, object]] = []
    events.extend(("sale", sale.created_at, sale) for sale in sales)
    events.extend(("adjustment", adjustment.adjusted_at, adjustment) for adjustment in adjustments)
    events.sort(key=lambda item: (item[1], 0 if item[0] == "sale" else 1))

    segments: list[dict[str, object | None]] = []
    current_segment: dict[str, object | None] | None = None

    def ensure_segment(start_reading: float, started_at: datetime | None) -> dict[str, object | None]:
        nonlocal current_segment
        if current_segment is None:
            current_segment = {
                "nozzle_id": nozzle.id,
                "start_reading": start_reading,
                "end_reading": start_reading,
                "sales_quantity": 0.0,
                "sales_count": 0,
                "shift_id": None,
                "started_at": started_at,
                "ended_at": started_at,
                "status": "open",
                "adjustment_event_id": None,
                "adjustment_reason": None,
            }
        return current_segment

    for event_type, event_time, payload in events:
        if event_type == "sale":
            sale = payload
            segment = ensure_segment(float(sale.opening_meter), sale.created_at)
            if segment["sales_count"] == 0 and segment["start_reading"] != sale.opening_meter:
                segment["start_reading"] = float(sale.opening_meter)
            segment["end_reading"] = float(sale.closing_meter)
            segment["sales_quantity"] = float(segment["sales_quantity"]) + float(sale.quantity)
            segment["sales_count"] = int(segment["sales_count"]) + 1
            segment["ended_at"] = sale.created_at
            if segment["shift_id"] is None:
                segment["shift_id"] = sale.shift_id
            elif segment["shift_id"] != sale.shift_id:
                segment["shift_id"] = None
            continue

        adjustment = payload
        segment = ensure_segment(float(adjustment.old_reading), adjustment.adjusted_at)
        segment["end_reading"] = float(adjustment.old_reading)
        segment["ended_at"] = adjustment.adjusted_at
        segment["status"] = "closed"
        segment["adjustment_event_id"] = adjustment.id
        segment["adjustment_reason"] = adjustment.reason
        segments.append(segment)
        current_segment = {
            "nozzle_id": nozzle.id,
            "start_reading": float(adjustment.new_reading),
            "end_reading": float(adjustment.new_reading),
            "sales_quantity": 0.0,
            "sales_count": 0,
            "shift_id": None,
            "started_at": adjustment.adjusted_at,
            "ended_at": adjustment.adjusted_at,
            "status": "open",
            "adjustment_event_id": None,
            "adjustment_reason": None,
        }

    if current_segment is None:
        current_segment = {
            "nozzle_id": nozzle.id,
            "start_reading": float(nozzle.current_segment_start_reading),
            "end_reading": float(nozzle.meter_reading or nozzle.current_segment_start_reading),
            "sales_quantity": float((nozzle.meter_reading or nozzle.current_segment_start_reading) - nozzle.current_segment_start_reading),
            "sales_count": 0,
            "shift_id": None,
            "started_at": nozzle.current_segment_started_at,
            "ended_at": None,
            "status": "open",
            "adjustment_event_id": None,
            "adjustment_reason": None,
        }
    else:
        current_segment["start_reading"] = float(nozzle.current_segment_start_reading)
        current_segment["end_reading"] = float(nozzle.meter_reading or nozzle.current_segment_start_reading)
        current_segment["ended_at"] = None if current_segment["status"] == "open" else current_segment["ended_at"]

    segments.append(current_segment)
    return segments
