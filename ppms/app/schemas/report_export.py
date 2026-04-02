from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class ReportExportCreate(BaseModel):
    report_type: str
    format: str = "csv"
    report_date: date | None = None
    station_id: int | None = None
    organization_id: int | None = None
    from_date: date | None = None
    to_date: date | None = None


class ReportExportResponse(BaseModel):
    id: int
    report_type: str
    format: str
    status: str
    station_id: int | None = None
    organization_id: int | None = None
    requested_by_user_id: int | None = None
    file_name: str
    content_type: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
