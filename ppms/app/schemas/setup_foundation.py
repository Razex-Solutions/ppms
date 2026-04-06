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


class SetupNozzleSummary(BaseModel):
    id: int
    name: str
    code: str
    dispenser_id: int
    tank_id: int
    fuel_type_id: int
    meter_reading: float
    current_segment_start_reading: float


class SetupDispenserSummary(BaseModel):
    id: int
    name: str
    code: str
    station_id: int
    location: str | None = None
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
