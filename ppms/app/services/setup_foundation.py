from datetime import time

from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.core.time import utc_now
from app.models.dispenser import Dispenser
from app.models.fuel_type import FuelType
from app.models.invoice_profile import InvoiceProfile
from app.models.nozzle import Nozzle
from app.models.organization import Organization
from app.models.organization_module_setting import OrganizationModuleSetting
from app.models.role import Role
from app.models.station import Station
from app.models.station_shift_template import StationShiftTemplate
from app.models.station_module_setting import StationModuleSetting
from app.models.tank import Tank
from app.models.user import User
from app.schemas.setup_foundation import (
    OnboardingInitialAdminInput,
    OnboardingModuleSettingInput,
    OnboardingStationDraftInput,
    OrganizationOnboardingApplyRequest,
    OrganizationOnboardingApplyResponse,
    OnboardingPendingIssueResponse,
    OnboardingStepStatusResponse,
    OrganizationSetupFoundationResponse,
    OrganizationOnboardingSummaryResponse,
    OrganizationStationSetupSummary,
    ResolvedBrandingSummary,
    ResolvedInvoiceIdentitySummary,
    StationSetupApplyRequest,
    SetupDispenserSummary,
    SetupFuelTypeSummary,
    SetupNozzleSummary,
    SetupTankSummary,
    StationSetupFoundationResponse,
    StationShiftTemplateInput,
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
                is_active=nozzle.is_active,
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
                is_active=item.is_active,
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
                is_active=item.is_active,
                nozzles=nozzle_map.get(item.id, []),
            )
            for item in dispensers
        ],
        tank_count=len(tanks),
        dispenser_count=len(dispensers),
        nozzle_count=len(nozzles),
    )


def build_organization_onboarding_summary(
    db: Session, organization: Organization
) -> OrganizationOnboardingSummaryResponse:
    stations = (
        db.query(Station)
        .filter(Station.organization_id == organization.id)
        .order_by(Station.id.asc())
        .all()
    )
    users = (
        db.query(User)
        .filter(User.organization_id == organization.id)
        .all()
    )
    org_modules = (
        db.query(OrganizationModuleSetting)
        .filter(OrganizationModuleSetting.organization_id == organization.id)
        .all()
    )

    target_station_count = organization.station_target_count
    current_station_count = len(stations)
    station_admin_count = sum(1 for user in users if user.role and user.role.name == "StationAdmin")
    head_office_count = sum(1 for user in users if user.role and user.role.name == "HeadOffice")
    completed_station_count = sum(1 for station in stations if station.setup_status == "completed")
    pending_station_count = current_station_count - completed_station_count

    pending_issues: list[OnboardingPendingIssueResponse] = []
    completed_steps = 0
    total_steps = 5

    organization_details_ready = bool(
        organization.name
        and organization.code
        and organization.contact_phone
        and organization.contact_email
    )
    if organization_details_ready:
        completed_steps += 1

    station_count_ready = target_station_count is not None and current_station_count >= target_station_count
    if station_count_ready:
        completed_steps += 1
    elif target_station_count is not None:
        pending_issues.append(
            OnboardingPendingIssueResponse(
                code="station_count_pending",
                title="Stations still need to be created",
                detail=f"Expected {target_station_count} stations but only {current_station_count} exist.",
                owner_scope="organization",
                owner_role="MasterAdmin",
            )
        )

    admin_assignment_ready = False
    if target_station_count == 1:
        admin_assignment_ready = head_office_count >= 1
        if not admin_assignment_ready:
            pending_issues.append(
                OnboardingPendingIssueResponse(
                    code="missing_head_office",
                    title="HeadOffice user is missing",
                    detail="A single-station organization still needs its HeadOffice user assigned.",
                    owner_scope="organization",
                    owner_role="MasterAdmin",
                )
            )
    else:
        admin_assignment_ready = head_office_count >= 1 and station_admin_count >= max(current_station_count, 1)
        if head_office_count < 1:
            pending_issues.append(
                OnboardingPendingIssueResponse(
                    code="missing_head_office",
                    title="HeadOffice user is missing",
                    detail="The organization needs at least one HeadOffice user.",
                    owner_scope="organization",
                    owner_role="MasterAdmin",
                )
            )
        if station_admin_count < max(current_station_count, 1):
            pending_issues.append(
                OnboardingPendingIssueResponse(
                    code="missing_station_admins",
                    title="Station admins still need assignment",
                    detail="One or more stations do not yet have a StationAdmin assignment.",
                    owner_scope="station",
                    owner_role="HeadOffice",
                )
            )
    if admin_assignment_ready:
        completed_steps += 1

    module_setup_ready = len(org_modules) > 0
    if module_setup_ready:
        completed_steps += 1
    else:
        pending_issues.append(
            OnboardingPendingIssueResponse(
                code="module_setup_pending",
                title="Organization modules are not configured",
                detail="Module enablement still needs to be confirmed for this organization.",
                owner_scope="organization",
                owner_role="MasterAdmin",
            )
        )

    forecourt_ready = completed_station_count == current_station_count and current_station_count > 0
    if forecourt_ready:
        completed_steps += 1
    else:
        for station in stations:
            if station.setup_status != "completed":
                pending_issues.append(
                    OnboardingPendingIssueResponse(
                        code="station_setup_incomplete",
                        title="Station setup is incomplete",
                        detail=f"{station.name} still has setup status '{station.setup_status}'.",
                        owner_scope="station",
                        owner_role="StationAdmin" if not station.is_head_office or current_station_count > 1 else "HeadOffice",
                        station_id=station.id,
                        station_name=station.name,
                    )
                )

    progress_percent = int((completed_steps / total_steps) * 100)
    overall_status = "completed" if completed_steps == total_steps else "in_progress"

    steps = [
        OnboardingStepStatusResponse(
            step_key="organization_details",
            title="Organization details",
            status="completed" if organization_details_ready else "pending",
            detail="Organization identity, contact, and branding basics are recorded." if organization_details_ready else "Organization details are still incomplete.",
        ),
        OnboardingStepStatusResponse(
            step_key="station_creation",
            title="Station creation",
            status="completed" if station_count_ready else "pending",
            detail=f"{current_station_count} of {target_station_count or current_station_count} target stations are available.",
        ),
        OnboardingStepStatusResponse(
            step_key="admin_assignment",
            title="Admin assignment",
            status="completed" if admin_assignment_ready else "pending",
            detail="Required HeadOffice and station admin assignments are in place." if admin_assignment_ready else "Required admin assignments are still incomplete.",
        ),
        OnboardingStepStatusResponse(
            step_key="module_configuration",
            title="Module configuration",
            status="completed" if module_setup_ready else "pending",
            detail="Organization module toggles have been configured." if module_setup_ready else "Organization modules still need to be configured.",
        ),
        OnboardingStepStatusResponse(
            step_key="station_setup",
            title="Station setup",
            status="completed" if forecourt_ready else "pending",
            detail="All stations have completed setup." if forecourt_ready else "One or more stations still have incomplete setup.",
        ),
    ]

    return OrganizationOnboardingSummaryResponse(
        organization_id=organization.id,
        organization_name=organization.name,
        organization_code=organization.code,
        onboarding_status=overall_status if organization.onboarding_status == "draft" else organization.onboarding_status,
        target_station_count=target_station_count,
        current_station_count=current_station_count,
        station_admin_count=station_admin_count,
        head_office_count=head_office_count,
        completed_station_count=completed_station_count,
        pending_station_count=pending_station_count,
        progress_percent=progress_percent,
        steps=steps,
        pending_issues=pending_issues,
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


def _slug_code(value: str, fallback: str) -> str:
    pieces = ["".join(ch for ch in chunk if ch.isalnum()).upper() for chunk in value.split()]
    code = "".join(piece[:3] for piece in pieces if piece)
    return code[:12] or fallback


def _unique_organization_code(db: Session, base_code: str, organization_id: int | None = None) -> str:
    code = base_code
    suffix = 1
    while True:
        existing = db.query(Organization).filter(Organization.code == code).first()
        if existing is None or existing.id == organization_id:
            return code
        suffix += 1
        code = f"{base_code[:9]}{suffix:02d}"


def _unique_station_code(db: Session, base_code: str, station_id: int | None = None) -> str:
    code = base_code
    suffix = 1
    while True:
        existing = db.query(Station).filter(Station.code == code).first()
        if existing is None or existing.id == station_id:
            return code
        suffix += 1
        code = f"{base_code[:10]}{suffix:02d}"


def _resolve_default_org_code(payload: OrganizationOnboardingApplyRequest) -> str:
    brand_seed = payload.brand_code or payload.brand_name or payload.name
    return _slug_code(brand_seed, "ORG")


def _default_station_name(organization: Organization, index: int, is_single_station: bool) -> str:
    if is_single_station:
        return organization.name
    return f"{organization.name} Station {index}"


def _default_station_code(organization: Organization, index: int) -> str:
    org_code = organization.code or "ORG"
    return f"{org_code}-S{index:02d}"


def _upsert_organization_module_settings(
    db: Session,
    organization: Organization,
    module_settings: list[OnboardingModuleSettingInput],
) -> None:
    for item in module_settings:
        existing = (
            db.query(OrganizationModuleSetting)
            .filter(
                OrganizationModuleSetting.organization_id == organization.id,
                OrganizationModuleSetting.module_name == item.module_name,
            )
            .first()
        )
        if existing is None:
            db.add(
                OrganizationModuleSetting(
                    organization_id=organization.id,
                    module_name=item.module_name,
                    is_enabled=item.is_enabled,
                )
            )
            continue
        existing.is_enabled = item.is_enabled
    db.flush()


def _upsert_station(
    db: Session,
    *,
    organization: Organization,
    station_payload: OnboardingStationDraftInput,
    index: int,
    station_id: int | None = None,
    is_single_station: bool,
) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first() if station_id else None
    if station is None:
        station = Station(
            organization_id=organization.id,
            name=station_payload.name or _default_station_name(organization, index, is_single_station),
            code=_default_station_code(organization, index),
        )
        db.add(station)

    station_name = station_payload.name or _default_station_name(organization, index, is_single_station)
    desired_code = station_payload.code or _default_station_code(organization, index)
    station.name = station_name
    station.code = _unique_station_code(db, desired_code, station.id)
    station.address = station_payload.address
    station.city = station_payload.city
    station.organization_id = organization.id
    station.is_head_office = station_payload.is_head_office if station_payload.is_head_office is not None else index == 1
    station.display_name = station_payload.display_name or station_name
    station.use_organization_branding = station_payload.use_organization_branding
    station.is_active = station_payload.is_active
    station.setup_status = station.setup_status or "draft"
    if station.use_organization_branding:
        station.brand_name = organization.brand_name
        station.brand_code = organization.brand_code
        station.logo_url = organization.logo_url
    db.flush()
    return station


def _upsert_initial_admin(
    db: Session,
    *,
    organization: Organization,
    stations: list[Station],
    admin_input: OnboardingInitialAdminInput,
    created_by_user_id: int | None,
) -> None:
    role_name = admin_input.role_name or ("HeadOffice" if len(stations) == 1 else "HeadOffice")
    role = db.query(Role).filter(Role.name == role_name).first()
    if role is None:
        return

    station_id: int | None = None
    scope_level = "organization"
    if role_name == "StationAdmin":
        scope_level = "station"
        target_station = None
        if admin_input.station_code:
            target_station = next((station for station in stations if station.code == admin_input.station_code), None)
        if target_station is None and len(stations) == 1:
            target_station = stations[0]
        station_id = target_station.id if target_station is not None else None

    user = db.query(User).filter(User.username == admin_input.username).first()
    if user is None:
        user = User(
            full_name=admin_input.full_name,
            username=admin_input.username,
            email=admin_input.email,
            phone=admin_input.phone,
            hashed_password=hash_password(admin_input.password),
            is_active=True,
            role_id=role.id,
            organization_id=organization.id,
            station_id=station_id,
            created_by_user_id=created_by_user_id,
            scope_level=scope_level,
            is_platform_user=False,
        )
        db.add(user)
        db.flush()
        return

    user.full_name = admin_input.full_name
    user.email = admin_input.email
    user.phone = admin_input.phone
    user.role_id = role.id
    user.organization_id = organization.id
    user.station_id = station_id
    user.scope_level = scope_level
    user.is_active = True
    user.created_by_user_id = created_by_user_id
    if admin_input.password:
        user.hashed_password = hash_password(admin_input.password)
    db.flush()


def apply_organization_onboarding(
    db: Session,
    *,
    payload: OrganizationOnboardingApplyRequest,
    current_user: User,
) -> OrganizationOnboardingApplyResponse:
    organization = None
    if payload.organization_id is not None:
        organization = db.query(Organization).filter(Organization.id == payload.organization_id).first()

    resolved_code = _unique_organization_code(
        db,
        payload.code or _resolve_default_org_code(payload),
        organization.id if organization is not None else None,
    )

    if organization is None:
        organization = Organization(
            name=payload.name,
            code=resolved_code,
        )
        db.add(organization)
        db.flush()

    organization.name = payload.name
    organization.code = resolved_code
    organization.description = payload.description
    organization.legal_name = payload.legal_name or payload.name
    organization.brand_catalog_id = payload.brand_catalog_id
    organization.brand_name = payload.brand_name or organization.brand_name
    organization.brand_code = payload.brand_code or organization.brand_code or resolved_code
    organization.logo_url = payload.logo_url
    organization.contact_email = payload.contact_email
    organization.contact_phone = payload.contact_phone
    organization.registration_number = payload.registration_number
    organization.tax_registration_number = payload.tax_registration_number
    organization.station_target_count = payload.station_target_count
    organization.inherit_branding_to_stations = payload.inherit_branding_to_stations
    organization.is_active = payload.is_active
    organization.onboarding_status = "in_progress"
    organization.billing_status = organization.billing_status or "trial"
    db.flush()

    _upsert_organization_module_settings(db, organization, payload.module_settings)

    existing_stations = (
        db.query(Station)
        .filter(Station.organization_id == organization.id)
        .order_by(Station.id.asc())
        .all()
    )
    created_or_updated_stations: list[Station] = []
    is_single_station = payload.station_target_count == 1
    for index in range(1, payload.station_target_count + 1):
        station_payload = payload.stations[index - 1] if index - 1 < len(payload.stations) else OnboardingStationDraftInput()
        existing_station_id = existing_stations[index - 1].id if index - 1 < len(existing_stations) else None
        station = _upsert_station(
            db,
            organization=organization,
            station_payload=station_payload,
            index=index,
            station_id=existing_station_id,
            is_single_station=is_single_station,
        )
        created_or_updated_stations.append(station)

    if payload.station_target_count == 1 and created_or_updated_stations:
        created_or_updated_stations[0].is_head_office = True

    if payload.initial_admin is not None:
        _upsert_initial_admin(
            db,
            organization=organization,
            stations=created_or_updated_stations,
            admin_input=payload.initial_admin,
            created_by_user_id=current_user.id,
        )

    db.commit()
    db.refresh(organization)
    for station in created_or_updated_stations:
        db.refresh(station)

    return OrganizationOnboardingApplyResponse(
        organization=build_organization_setup_foundation(db, organization),
        onboarding_summary=build_organization_onboarding_summary(db, organization),
    )


def _parse_time_label(value: str) -> time:
    parts = value.split(":")
    if len(parts) < 2:
        raise ValueError("Time values must be in HH:MM format")
    return time(int(parts[0]), int(parts[1]))


def _generated_shift_templates(shift_mode: str) -> list[StationShiftTemplateInput]:
    if shift_mode == "single_24h":
        return [StationShiftTemplateInput(name="Full Day", start_time="00:00", end_time="00:00")]
    if shift_mode == "two_12h":
        return [
            StationShiftTemplateInput(name="Day", start_time="06:00", end_time="18:00"),
            StationShiftTemplateInput(name="Night", start_time="18:00", end_time="06:00"),
        ]
    return [
        StationShiftTemplateInput(name="Morning", start_time="06:00", end_time="14:00"),
        StationShiftTemplateInput(name="Evening", start_time="14:00", end_time="22:00"),
        StationShiftTemplateInput(name="Night", start_time="22:00", end_time="06:00"),
    ]


def _upsert_station_module_setting(db: Session, station_id: int, module_name: str, is_enabled: bool) -> None:
    existing = (
        db.query(StationModuleSetting)
        .filter(
            StationModuleSetting.station_id == station_id,
            StationModuleSetting.module_name == module_name,
        )
        .first()
    )
    if existing is None:
        db.add(StationModuleSetting(station_id=station_id, module_name=module_name, is_enabled=is_enabled))
        db.flush()
        return
    existing.is_enabled = is_enabled
    db.flush()


def apply_station_setup(
    db: Session,
    *,
    station: Station,
    payload: StationSetupApplyRequest,
) -> StationSetupFoundationResponse:
    if payload.display_name is not None:
        station.display_name = payload.display_name
    if payload.has_shops is not None:
        station.has_shops = payload.has_shops
    if payload.has_pos is not None:
        station.has_pos = payload.has_pos
        _upsert_station_module_setting(db, station.id, "pos", payload.has_pos)
    if payload.has_tankers is not None:
        station.has_tankers = payload.has_tankers
        _upsert_station_module_setting(db, station.id, "tanker_operations", payload.has_tankers)
    if payload.has_hardware is not None:
        station.has_hardware = payload.has_hardware
        _upsert_station_module_setting(db, station.id, "hardware", payload.has_hardware)
    if payload.allow_meter_adjustments is not None:
        station.allow_meter_adjustments = payload.allow_meter_adjustments
        _upsert_station_module_setting(db, station.id, "meter_adjustments", payload.allow_meter_adjustments)

    fuel_type_by_key: dict[str, FuelType] = {}
    for item in payload.fuel_types:
        fuel_type = None
        if item.id is not None:
            fuel_type = db.query(FuelType).filter(FuelType.id == item.id).first()
        if fuel_type is None:
            fuel_type = db.query(FuelType).filter(FuelType.name == item.name).first()
        if fuel_type is None:
            fuel_type = FuelType(name=item.name, description=item.description)
            db.add(fuel_type)
            db.flush()
        else:
            fuel_type.description = item.description
            db.flush()
        fuel_type_by_key[str(fuel_type.id)] = fuel_type
        fuel_type_by_key[fuel_type.name.lower()] = fuel_type

    tank_by_key: dict[str, Tank] = {}
    for index, item in enumerate(payload.tanks, start=1):
        fuel_type = None
        if item.fuel_type_id is not None:
            fuel_type = fuel_type_by_key.get(str(item.fuel_type_id)) or db.query(FuelType).filter(FuelType.id == item.fuel_type_id).first()
        elif item.fuel_type_name is not None:
            fuel_type = fuel_type_by_key.get(item.fuel_type_name.lower()) or db.query(FuelType).filter(FuelType.name == item.fuel_type_name).first()
        if fuel_type is None:
            raise ValueError(f"Unable to resolve fuel type for tank {item.name or index}")

        desired_tank_code = item.code or f"{station.code}-T{index}"
        tank = db.query(Tank).filter(Tank.id == item.id).first() if item.id is not None else None
        if tank is None:
            tank = db.query(Tank).filter(Tank.code == desired_tank_code).first()
        if tank is None:
            tank = Tank(
                station_id=station.id,
                name=item.name or f"{fuel_type.name} Tank {index}",
                code=desired_tank_code,
                fuel_type_id=fuel_type.id,
                capacity=item.capacity,
            )
            db.add(tank)

        tank.name = item.name or f"{fuel_type.name} Tank {index}"
        tank.code = desired_tank_code
        tank.station_id = station.id
        tank.fuel_type_id = fuel_type.id
        tank.capacity = item.capacity
        tank.current_volume = item.current_volume
        tank.low_stock_threshold = item.low_stock_threshold
        tank.location = None
        tank.is_active = item.is_active
        db.flush()
        tank_by_key[str(tank.id)] = tank
        tank_by_key[tank.code] = tank

    for dispenser_index, dispenser_input in enumerate(payload.dispensers, start=1):
        desired_dispenser_code = dispenser_input.code or f"{station.code}-D{dispenser_index}"
        dispenser = db.query(Dispenser).filter(Dispenser.id == dispenser_input.id).first() if dispenser_input.id is not None else None
        if dispenser is None:
            dispenser = db.query(Dispenser).filter(Dispenser.code == desired_dispenser_code).first()
        if dispenser is None:
            dispenser = Dispenser(
                station_id=station.id,
                name=dispenser_input.name or f"Dispenser {dispenser_index}",
                code=desired_dispenser_code,
            )
            db.add(dispenser)

        dispenser.name = dispenser_input.name or f"Dispenser {dispenser_index}"
        dispenser.code = desired_dispenser_code
        dispenser.station_id = station.id
        dispenser.location = None
        dispenser.is_active = dispenser_input.is_active
        db.flush()

        for nozzle_index, nozzle_input in enumerate(dispenser_input.nozzles, start=1):
            tank = None
            if nozzle_input.tank_id is not None:
                tank = tank_by_key.get(str(nozzle_input.tank_id)) or db.query(Tank).filter(Tank.id == nozzle_input.tank_id).first()
            elif nozzle_input.tank_code is not None:
                tank = tank_by_key.get(nozzle_input.tank_code) or db.query(Tank).filter(Tank.code == nozzle_input.tank_code).first()
            if tank is None:
                raise ValueError(f"Unable to resolve tank for nozzle {nozzle_input.name or nozzle_index}")

            fuel_type = None
            if nozzle_input.fuel_type_id is not None:
                fuel_type = fuel_type_by_key.get(str(nozzle_input.fuel_type_id)) or db.query(FuelType).filter(FuelType.id == nozzle_input.fuel_type_id).first()
            elif nozzle_input.fuel_type_name is not None:
                fuel_type = fuel_type_by_key.get(nozzle_input.fuel_type_name.lower()) or db.query(FuelType).filter(FuelType.name == nozzle_input.fuel_type_name).first()
            if fuel_type is None:
                fuel_type = db.query(FuelType).filter(FuelType.id == tank.fuel_type_id).first()

            desired_nozzle_code = nozzle_input.code or f"{dispenser.code}-N{nozzle_index}"
            nozzle = db.query(Nozzle).filter(Nozzle.id == nozzle_input.id).first() if nozzle_input.id is not None else None
            if nozzle is None:
                nozzle = db.query(Nozzle).filter(Nozzle.code == desired_nozzle_code).first()
            if nozzle is None:
                nozzle = Nozzle(
                    name=nozzle_input.name or f"Nozzle {nozzle_index}",
                    code=desired_nozzle_code,
                    dispenser_id=dispenser.id,
                    tank_id=tank.id,
                    fuel_type_id=fuel_type.id,
                )
                db.add(nozzle)

            nozzle.name = nozzle_input.name or f"Nozzle {nozzle_index}"
            nozzle.code = desired_nozzle_code
            nozzle.dispenser_id = dispenser.id
            nozzle.tank_id = tank.id
            nozzle.fuel_type_id = fuel_type.id
            nozzle.meter_reading = nozzle_input.meter_reading
            nozzle.is_active = nozzle_input.is_active
            if nozzle.current_segment_start_reading is None:
                nozzle.current_segment_start_reading = nozzle_input.meter_reading
            db.flush()

    desired_templates = payload.shift_templates or _generated_shift_templates(payload.shift_mode)
    existing_templates = (
        db.query(StationShiftTemplate)
        .filter(StationShiftTemplate.station_id == station.id)
        .order_by(StationShiftTemplate.id.asc())
        .all()
    )
    for template in existing_templates:
        template.is_active = False
    db.flush()
    for item in desired_templates:
        template = (
            db.query(StationShiftTemplate)
            .filter(
                StationShiftTemplate.station_id == station.id,
                StationShiftTemplate.name == item.name,
            )
            .first()
        )
        if template is None:
            template = StationShiftTemplate(
                station_id=station.id,
                name=item.name,
                start_time=_parse_time_label(item.start_time),
                end_time=_parse_time_label(item.end_time),
                is_active=item.is_active,
            )
            db.add(template)
        template.start_time = _parse_time_label(item.start_time)
        template.end_time = _parse_time_label(item.end_time)
        template.is_active = item.is_active
        db.flush()

    station.setup_status = payload.setup_status or "completed"
    if station.setup_status == "completed":
        station.setup_completed_at = utc_now()
    if station.organization is not None:
        sibling_stations = [item for item in station.organization.stations]
        if sibling_stations and all(item.setup_status == "completed" for item in sibling_stations):
            station.organization.onboarding_status = "active"
        else:
            station.organization.onboarding_status = "in_progress"

    db.commit()
    db.refresh(station)
    return build_station_setup_foundation(db, station)
