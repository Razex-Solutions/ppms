from pydantic import BaseModel, ConfigDict


class OrganizationCreate(BaseModel):
    name: str
    code: str
    description: str | None = None
    legal_name: str | None = None
    brand_catalog_id: int | None = None
    brand_name: str | None = None
    brand_code: str | None = None
    logo_url: str | None = None
    contact_email: str | None = None
    contact_phone: str | None = None
    registration_number: str | None = None
    tax_registration_number: str | None = None
    onboarding_status: str = "draft"
    billing_status: str = "trial"
    station_target_count: int | None = None
    inherit_branding_to_stations: bool = True
    is_active: bool = True


class OrganizationUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    description: str | None = None
    legal_name: str | None = None
    brand_catalog_id: int | None = None
    brand_name: str | None = None
    brand_code: str | None = None
    logo_url: str | None = None
    contact_email: str | None = None
    contact_phone: str | None = None
    registration_number: str | None = None
    tax_registration_number: str | None = None
    onboarding_status: str | None = None
    billing_status: str | None = None
    station_target_count: int | None = None
    inherit_branding_to_stations: bool | None = None
    is_active: bool | None = None


class OrganizationResponse(BaseModel):
    id: int
    name: str
    code: str
    description: str | None = None
    legal_name: str | None = None
    brand_catalog_id: int | None = None
    brand_name: str | None = None
    brand_code: str | None = None
    logo_url: str | None = None
    contact_email: str | None = None
    contact_phone: str | None = None
    registration_number: str | None = None
    tax_registration_number: str | None = None
    onboarding_status: str
    billing_status: str
    station_target_count: int | None = None
    inherit_branding_to_stations: bool
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class OrganizationDashboardRoleCount(BaseModel):
    role_name: str
    user_count: int


class OrganizationDashboardModuleStatus(BaseModel):
    module_name: str
    enabled_station_count: int
    total_station_count: int
    fully_enabled: bool


class OrganizationDashboardSummaryResponse(BaseModel):
    organization_id: int
    organization_name: str
    organization_code: str
    active_station_count: int
    inactive_station_count: int
    completed_station_setup_count: int
    pending_station_setup_count: int
    active_forecourt_tank_count: int
    active_forecourt_dispenser_count: int
    active_forecourt_nozzle_count: int
    open_shift_count: int
    active_staff_count: int
    pending_customer_balance_total: float
    pending_supplier_balance_total: float
    unread_notification_count: int
    role_counts: list[OrganizationDashboardRoleCount]
    module_statuses: list[OrganizationDashboardModuleStatus]
