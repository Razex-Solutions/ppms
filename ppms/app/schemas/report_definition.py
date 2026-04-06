from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ReportDefinitionCreate(BaseModel):
    name: str
    report_type: str
    station_id: int | None = None
    organization_id: int | None = None
    is_shared: bool = False
    filters: dict[str, object] = {}


class ReportDefinitionUpdate(BaseModel):
    name: str | None = None
    is_shared: bool | None = None
    filters: dict[str, object] | None = None


class ReportDefinitionResponse(BaseModel):
    id: int
    name: str
    report_type: str
    station_id: int | None = None
    organization_id: int | None = None
    created_by_user_id: int | None = None
    is_shared: bool
    filters: dict[str, object] = {}
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
