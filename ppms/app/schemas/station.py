from datetime import datetime

from pydantic import BaseModel, ConfigDict


class StationCreate(BaseModel):
    name: str
    code: str
    address: str | None = None
    city: str | None = None
    organization_id: int
    is_head_office: bool = False
    display_name: str | None = None
    legal_name_override: str | None = None
    brand_name: str | None = None
    brand_code: str | None = None
    logo_url: str | None = None
    use_organization_branding: bool = True
    is_active: bool = True
    setup_status: str = "draft"
    has_shops: bool = False
    has_pos: bool = False
    has_tankers: bool = False
    has_hardware: bool = False
    allow_meter_adjustments: bool = True


class StationUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    address: str | None = None
    city: str | None = None
    organization_id: int | None = None
    is_head_office: bool | None = None
    display_name: str | None = None
    legal_name_override: str | None = None
    brand_name: str | None = None
    brand_code: str | None = None
    logo_url: str | None = None
    use_organization_branding: bool | None = None
    is_active: bool | None = None
    setup_status: str | None = None
    setup_completed_at: datetime | None = None
    has_shops: bool | None = None
    has_pos: bool | None = None
    has_tankers: bool | None = None
    has_hardware: bool | None = None
    allow_meter_adjustments: bool | None = None


class StationResponse(BaseModel):
    id: int
    name: str
    code: str
    address: str | None = None
    city: str | None = None
    organization_id: int | None = None
    is_head_office: bool
    display_name: str | None = None
    legal_name_override: str | None = None
    brand_name: str | None = None
    brand_code: str | None = None
    logo_url: str | None = None
    use_organization_branding: bool
    is_active: bool
    setup_status: str
    setup_completed_at: datetime | None = None
    has_shops: bool
    has_pos: bool
    has_tankers: bool
    has_hardware: bool
    allow_meter_adjustments: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
