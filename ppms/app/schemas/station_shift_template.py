from datetime import datetime, time

from pydantic import BaseModel, ConfigDict, field_validator


class StationShiftTemplateBase(BaseModel):
    name: str
    start_time: time
    end_time: time
    is_active: bool = True

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Shift template name is required")
        return normalized


class StationShiftTemplateCreate(StationShiftTemplateBase):
    pass


class StationShiftTemplateUpdate(BaseModel):
    name: str | None = None
    start_time: time | None = None
    end_time: time | None = None
    is_active: bool | None = None

    @field_validator("name")
    @classmethod
    def validate_optional_name(cls, value: str | None) -> str | None:
        if value is None:
            return value
        normalized = value.strip()
        if not normalized:
            raise ValueError("Shift template name is required")
        return normalized


class StationShiftTemplateResponse(BaseModel):
    id: int
    station_id: int
    name: str
    start_time: time
    end_time: time
    is_active: bool
    covers_full_day: bool
    window_label: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
