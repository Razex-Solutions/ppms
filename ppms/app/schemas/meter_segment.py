from datetime import datetime

from pydantic import BaseModel


class MeterSegmentResponse(BaseModel):
    nozzle_id: int
    start_reading: float
    end_reading: float
    sales_quantity: float
    sales_count: int
    shift_id: int | None = None
    started_at: datetime | None = None
    ended_at: datetime | None = None
    status: str
    adjustment_event_id: int | None = None
    adjustment_reason: str | None = None
