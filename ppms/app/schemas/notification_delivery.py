from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificationDeliveryResponse(BaseModel):
    id: int
    notification_id: int
    channel: str
    destination: str | None = None
    status: str
    detail: str | None = None
    attempts_count: int
    last_attempt_at: datetime | None = None
    next_retry_at: datetime | None = None
    processed_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
