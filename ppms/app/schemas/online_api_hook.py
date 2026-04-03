from datetime import datetime

from pydantic import BaseModel, ConfigDict


class OnlineAPIHookCreate(BaseModel):
    name: str
    event_type: str
    target_url: str
    auth_type: str = "none"
    auth_token: str | None = None
    secret_key: str | None = None
    is_active: bool = False


class OnlineAPIHookUpdate(BaseModel):
    name: str | None = None
    event_type: str | None = None
    target_url: str | None = None
    auth_type: str | None = None
    auth_token: str | None = None
    secret_key: str | None = None
    is_active: bool | None = None


class OnlineAPIHookPing(BaseModel):
    payload: dict | None = None


class OnlineAPIHookResponse(BaseModel):
    id: int
    organization_id: int
    name: str
    event_type: str
    target_url: str
    auth_type: str
    is_active: bool
    last_status: str | None = None
    last_detail: str | None = None
    last_triggered_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
