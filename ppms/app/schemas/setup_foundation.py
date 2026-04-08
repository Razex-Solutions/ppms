from pydantic import BaseModel


class ResolvedBrandingSummary(BaseModel):
    brand_name: str | None = None
    brand_code: str | None = None
    logo_url: str | None = None
    source: str


class SetupFuelTypeSummary(BaseModel):
    id: int
    name: str
    description: str | None = None


class SetupTankSummary(BaseModel):
    id: int
    name: str
    code: str
    station_id: int
    fuel_type_id: int
    capacity: float
    current_volume: float
    low_stock_threshold: float
    location: str | None = None
    is_active: bool


class SetupNozzleSummary(BaseModel):
    id: int
    name: str
    code: str
    dispenser_id: int
    tank_id: int
    fuel_type_id: int
    meter_reading: float
    current_segment_start_reading: float
    is_active: bool


class SetupDispenserSummary(BaseModel):
    id: int
    name: str
    code: str
    station_id: int
    location: str | None = None
    is_active: bool
    nozzles: list[SetupNozzleSummary]


class ResolvedInvoiceIdentitySummary(BaseModel):
    business_name: str
    legal_name: str | None = None
    brand_name: str | None = None
    brand_code: str | None = None
    logo_url: str | None = None
    contact_email: str | None = None
    contact_phone: str | None = None
    footer_text: str | None = None
    source: str


class StationSetupFoundationResponse(BaseModel):
    station_id: int
    organization_id: int | None = None
    station_name: str
    station_code: str
    setup_status: str
    resolved_branding: ResolvedBrandingSummary
    resolved_legal_name: str
    invoice_identity: ResolvedInvoiceIdentitySummary
    fuel_types: list[SetupFuelTypeSummary]
    tanks: list[SetupTankSummary]
    dispensers: list[SetupDispenserSummary]
    tank_count: int
    dispenser_count: int
    nozzle_count: int


class OrganizationStationSetupSummary(BaseModel):
    id: int
    name: str
    code: str
    is_head_office: bool
    setup_status: str
    resolved_branding: ResolvedBrandingSummary


class OrganizationSetupFoundationResponse(BaseModel):
    organization_id: int
    organization_name: str
    organization_code: str
    legal_name: str | None = None
    onboarding_status: str
    station_target_count: int | None = None
    inherit_branding_to_stations: bool
    resolved_branding: ResolvedBrandingSummary
    stations: list[OrganizationStationSetupSummary]


class OnboardingPendingIssueResponse(BaseModel):
    code: str
    title: str
    detail: str
    owner_scope: str
    owner_role: str
    station_id: int | None = None
    station_name: str | None = None
    blocking: bool = True


class OnboardingStepStatusResponse(BaseModel):
    step_key: str
    title: str
    status: str
    detail: str
    blocking: bool = True


class OrganizationOnboardingSummaryResponse(BaseModel):
    organization_id: int
    organization_name: str
    organization_code: str
    onboarding_status: str
    target_station_count: int | None = None
    current_station_count: int
    station_admin_count: int
    head_office_count: int
    completed_station_count: int
    pending_station_count: int
    progress_percent: int
    steps: list[OnboardingStepStatusResponse]
    pending_issues: list[OnboardingPendingIssueResponse]


class OnboardingModuleSettingInput(BaseModel):
    module_name: str
    is_enabled: bool


class OnboardingStationDraftInput(BaseModel):
    name: str | None = None
    code: str | None = None
    address: str | None = None
    city: str | None = None
    is_head_office: bool | None = None
    display_name: str | None = None
    use_organization_branding: bool = True
    is_active: bool = True


class OnboardingInitialAdminInput(BaseModel):
    full_name: str
    username: str
    email: str | None = None
    phone: str | None = None
    password: str
    role_name: str | None = None
    station_code: str | None = None


class OrganizationOnboardingApplyRequest(BaseModel):
    organization_id: int | None = None
    name: str
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
    station_target_count: int
    inherit_branding_to_stations: bool = True
    is_active: bool = True
    module_settings: list[OnboardingModuleSettingInput] = []
    stations: list[OnboardingStationDraftInput] = []
    initial_admin: OnboardingInitialAdminInput | None = None


class OrganizationOnboardingApplyResponse(BaseModel):
    organization: OrganizationSetupFoundationResponse
    onboarding_summary: OrganizationOnboardingSummaryResponse


class StationSetupFuelTypeInput(BaseModel):
    id: int | None = None
    name: str
    description: str | None = None


class StationSetupTankInput(BaseModel):
    id: int | None = None
    name: str | None = None
    code: str | None = None
    fuel_type_id: int | None = None
    fuel_type_name: str | None = None
    capacity: float
    low_stock_threshold: float = 1000
    current_volume: float = 0
    is_active: bool = True


class StationSetupNozzleInput(BaseModel):
    id: int | None = None
    name: str | None = None
    code: str | None = None
    tank_id: int | None = None
    tank_code: str | None = None
    fuel_type_id: int | None = None
    fuel_type_name: str | None = None
    meter_reading: float = 0
    is_active: bool = True


class StationSetupDispenserInput(BaseModel):
    id: int | None = None
    name: str | None = None
    code: str | None = None
    is_active: bool = True
    nozzles: list[StationSetupNozzleInput] = []


class StationShiftTemplateInput(BaseModel):
    name: str
    start_time: str
    end_time: str
    is_active: bool = True


class StationSetupApplyRequest(BaseModel):
    display_name: str | None = None
    setup_status: str | None = None
    has_shops: bool | None = None
    has_pos: bool | None = None
    has_tankers: bool | None = None
    has_hardware: bool | None = None
    allow_meter_adjustments: bool | None = None
    fuel_types: list[StationSetupFuelTypeInput] = []
    tanks: list[StationSetupTankInput] = []
    dispensers: list[StationSetupDispenserInput] = []
    shift_mode: str = "three_8h"
    shift_templates: list[StationShiftTemplateInput] = []
