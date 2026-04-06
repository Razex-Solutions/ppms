from sqlalchemy.orm import Session

from app.models.dispenser import Dispenser
from app.models.fuel_type import FuelType
from app.models.invoice_profile import InvoiceProfile
from app.models.nozzle import Nozzle
from app.models.organization import Organization
from app.models.station import Station
from app.models.tank import Tank
from app.schemas.setup_foundation import (
    OrganizationSetupFoundationResponse,
    OrganizationStationSetupSummary,
    ResolvedBrandingSummary,
    ResolvedInvoiceIdentitySummary,
    SetupDispenserSummary,
    SetupFuelTypeSummary,
    SetupNozzleSummary,
    SetupTankSummary,
    StationSetupFoundationResponse,
)
from app.services.invoice_profiles import get_or_create_invoice_profile


def resolve_station_branding(station: Station) -> ResolvedBrandingSummary:
    organization = station.organization
    if station.use_organization_branding and organization is not None:
        return ResolvedBrandingSummary(
            brand_name=organization.brand_name or station.brand_name,
            brand_code=organization.brand_code or station.brand_code,
            logo_url=organization.logo_url or station.logo_url,
            source="organization",
        )
    return ResolvedBrandingSummary(
        brand_name=station.brand_name,
        brand_code=station.brand_code,
        logo_url=station.logo_url,
        source="station",
    )


def resolve_organization_branding(organization: Organization) -> ResolvedBrandingSummary:
    return ResolvedBrandingSummary(
        brand_name=organization.brand_name,
        brand_code=organization.brand_code,
        logo_url=organization.logo_url,
        source="organization",
    )


def resolve_station_legal_name(station: Station) -> str:
    organization = station.organization
    return (
        station.legal_name_override
        or (organization.legal_name if organization is not None else None)
        or station.name
    )


def resolve_invoice_identity(station: Station, profile: InvoiceProfile) -> ResolvedInvoiceIdentitySummary:
    branding = resolve_station_branding(station)
    source = "invoice_profile"
    if not profile.contact_email and not profile.contact_phone and not profile.footer_text:
        source = "station_defaults"
    return ResolvedInvoiceIdentitySummary(
        business_name=profile.business_name or station.name,
        legal_name=profile.legal_name or resolve_station_legal_name(station),
        brand_name=branding.brand_name,
        brand_code=branding.brand_code,
        logo_url=profile.logo_url or branding.logo_url,
        contact_email=profile.contact_email,
        contact_phone=profile.contact_phone,
        footer_text=profile.footer_text,
        source=source,
    )


def build_station_setup_foundation(db: Session, station: Station) -> StationSetupFoundationResponse:
    profile = get_or_create_invoice_profile(db, station)
    fuel_types = db.query(FuelType).order_by(FuelType.name.asc()).all()
    tanks = (
        db.query(Tank)
        .filter(Tank.station_id == station.id)
        .order_by(Tank.id.asc())
        .all()
    )
    dispensers = (
        db.query(Dispenser)
        .filter(Dispenser.station_id == station.id)
        .order_by(Dispenser.id.asc())
        .all()
    )
    nozzles = (
        db.query(Nozzle)
        .join(Dispenser, Dispenser.id == Nozzle.dispenser_id)
        .filter(Dispenser.station_id == station.id)
        .order_by(Nozzle.id.asc())
        .all()
    )
    nozzle_map: dict[int, list[SetupNozzleSummary]] = {}
    for nozzle in nozzles:
        nozzle_map.setdefault(nozzle.dispenser_id, []).append(
            SetupNozzleSummary(
                id=nozzle.id,
                name=nozzle.name,
                code=nozzle.code,
                dispenser_id=nozzle.dispenser_id,
                tank_id=nozzle.tank_id,
                fuel_type_id=nozzle.fuel_type_id,
                meter_reading=nozzle.meter_reading,
                current_segment_start_reading=nozzle.current_segment_start_reading,
            )
        )

    return StationSetupFoundationResponse(
        station_id=station.id,
        organization_id=station.organization_id,
        station_name=station.name,
        station_code=station.code,
        setup_status=station.setup_status,
        resolved_branding=resolve_station_branding(station),
        resolved_legal_name=resolve_station_legal_name(station),
        invoice_identity=resolve_invoice_identity(station, profile),
        fuel_types=[
            SetupFuelTypeSummary(id=item.id, name=item.name, description=item.description)
            for item in fuel_types
        ],
        tanks=[
            SetupTankSummary(
                id=item.id,
                name=item.name,
                code=item.code,
                station_id=item.station_id,
                fuel_type_id=item.fuel_type_id,
                capacity=item.capacity,
                current_volume=item.current_volume,
                low_stock_threshold=item.low_stock_threshold,
                location=item.location,
            )
            for item in tanks
        ],
        dispensers=[
            SetupDispenserSummary(
                id=item.id,
                name=item.name,
                code=item.code,
                station_id=item.station_id,
                location=item.location,
                nozzles=nozzle_map.get(item.id, []),
            )
            for item in dispensers
        ],
        tank_count=len(tanks),
        dispenser_count=len(dispensers),
        nozzle_count=len(nozzles),
    )


def build_organization_setup_foundation(
    db: Session, organization: Organization
) -> OrganizationSetupFoundationResponse:
    stations = (
        db.query(Station)
        .filter(Station.organization_id == organization.id)
        .order_by(Station.id.asc())
        .all()
    )
    return OrganizationSetupFoundationResponse(
        organization_id=organization.id,
        organization_name=organization.name,
        organization_code=organization.code,
        legal_name=organization.legal_name,
        onboarding_status=organization.onboarding_status,
        station_target_count=organization.station_target_count,
        inherit_branding_to_stations=organization.inherit_branding_to_stations,
        resolved_branding=resolve_organization_branding(organization),
        stations=[
            OrganizationStationSetupSummary(
                id=station.id,
                name=station.name,
                code=station.code,
                is_head_office=station.is_head_office,
                setup_status=station.setup_status,
                resolved_branding=resolve_station_branding(station),
            )
            for station in stations
        ],
    )
