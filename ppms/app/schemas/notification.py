from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificationResponse(BaseModel):
    id: int
    recipient_user_id: int
    actor_user_id: int | None
    station_id: int | None
    organization_id: int | None
    event_type: str
    title: str
    message: str
    entity_type: str | None
    entity_id: int | None
    is_read: bool
    created_at: datetime
    read_at: datetime | None

    model_config = ConfigDict(from_attributes=True)
