from datetime import datetime

from pydantic import BaseModel, ConfigDict


class AuditLogResponse(BaseModel):
    id: int
    user_id: int | None = None
    username: str | None = None
    station_id: int | None = None
    module: str
    action: str
    entity_type: str
    entity_id: int | None = None
    details_json: str | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
