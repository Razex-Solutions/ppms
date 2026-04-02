from pydantic import BaseModel, ConfigDict


class NotificationPreferenceUpdate(BaseModel):
    event_type: str
    in_app_enabled: bool = True
    email_enabled: bool = False
    sms_enabled: bool = False
    whatsapp_enabled: bool = False


class NotificationPreferenceResponse(BaseModel):
    id: int
    user_id: int
    event_type: str
    in_app_enabled: bool
    email_enabled: bool
    sms_enabled: bool
    whatsapp_enabled: bool

    model_config = ConfigDict(from_attributes=True)
