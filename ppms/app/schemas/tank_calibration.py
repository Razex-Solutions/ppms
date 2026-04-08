from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class TankCalibrationChartLineInput(BaseModel):
    dip_mm: float
    volume_liters: float
    water_mm: float | None = None
    sort_order: int | None = None


class TankCalibrationChartCreate(BaseModel):
    tank_id: int
    version_no: int = 1
    source_type: str = "manual"
    document_reference: str | None = None
    notes: str | None = None
    is_active: bool = True
    lines: list[TankCalibrationChartLineInput] = Field(default_factory=list, min_length=2)


class TankCalibrationChartUpdate(BaseModel):
    version_no: int | None = None
    source_type: str | None = None
    document_reference: str | None = None
    notes: str | None = None
    is_active: bool | None = None
    lines: list[TankCalibrationChartLineInput] | None = None


class TankCalibrationChartLineResponse(BaseModel):
    id: int
    dip_mm: float
    volume_liters: float
    water_mm: float | None = None
    sort_order: int

    model_config = ConfigDict(from_attributes=True)


class TankCalibrationChartResponse(BaseModel):
    id: int
    tank_id: int
    version_no: int
    source_type: str
    document_reference: str | None = None
    notes: str | None = None
    is_active: bool
    created_by_user_id: int | None = None
    created_at: datetime
    lines: list[TankCalibrationChartLineResponse]

    model_config = ConfigDict(from_attributes=True)
