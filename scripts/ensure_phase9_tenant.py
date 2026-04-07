"""Prepare the local Phase 9 tenant used by the clean Flutter rebuild.

Run from the repository root:
    venv\\Scripts\\python.exe scripts\\ensure_phase9_tenant.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ppms"))

from app.core.database import SessionLocal  # noqa: E402
from app.core.permissions import ROLE_CAPABILITY_SUMMARY  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.models.brand_catalog import BrandCatalog  # noqa: E402
from app.models.dispenser import Dispenser  # noqa: E402
from app.models.fuel_type import FuelType  # noqa: E402
from app.models.invoice_profile import InvoiceProfile  # noqa: E402
from app.models.nozzle import Nozzle  # noqa: E402
from app.models.organization import Organization  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.station import Station  # noqa: E402
from app.models.tank import Tank  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.station_modules import set_station_module  # noqa: E402


def ensure_role(db, name: str) -> Role:
    role = db.query(Role).filter(Role.name == name).first()
    if role:
        return role
    role = Role(
        name=name,
        description=ROLE_CAPABILITY_SUMMARY.get(name, {}).get(
            "governance",
            f"{name} role",
        ),
    )
    db.add(role)
    db.commit()
    db.refresh(role)
    return role


def ensure_brand(db) -> BrandCatalog:
    brand = db.query(BrandCatalog).filter(BrandCatalog.code == "PSO").first()
    if brand:
        brand.is_active = True
        db.commit()
        return brand
    brand = BrandCatalog(
        code="PSO",
        name="PSO",
        logo_url="https://psopk.com/assets/images/homepage/logo.png",
        primary_color="#00539B",
        sort_order=10,
        is_active=True,
    )
    db.add(brand)
    db.commit()
    db.refresh(brand)
    return brand


def ensure_organization(db, brand: BrandCatalog) -> Organization:
    organization = (
        db.query(Organization)
        .filter((Organization.code == "CHECK-PSO-004") | (Organization.name == "check"))
        .order_by(Organization.id.desc())
        .first()
    )
    if not organization:
        organization = Organization(
            name="check",
            code="CHECK-PSO-004",
            description="Phase 9 single-station tenant",
            legal_name="check",
            brand_catalog_id=brand.id,
            brand_name=brand.name,
            brand_code=brand.code,
            logo_url=brand.logo_url,
            onboarding_status="active",
            billing_status="local",
            station_target_count=1,
            inherit_branding_to_stations=True,
            is_active=True,
        )
        db.add(organization)
        db.commit()
        db.refresh(organization)
    else:
        organization.name = "check"
        organization.legal_name = organization.legal_name or "check"
        organization.brand_catalog_id = brand.id
        organization.brand_name = brand.name
        organization.brand_code = brand.code
        organization.logo_url = organization.logo_url or brand.logo_url
        organization.onboarding_status = "active"
        organization.billing_status = organization.billing_status or "local"
        organization.station_target_count = 1
        organization.inherit_branding_to_stations = True
        organization.is_active = True
        db.commit()
    return organization


def ensure_named_organization(
    db,
    *,
    name: str,
    code: str,
    description: str,
    station_target_count: int,
    brand: BrandCatalog,
) -> Organization:
    organization = (
        db.query(Organization)
        .filter((Organization.code == code) | (Organization.name == name))
        .order_by(Organization.id.desc())
        .first()
    )
    if not organization:
        organization = Organization(
            name=name,
            code=code,
            description=description,
            legal_name=name,
            brand_catalog_id=brand.id,
            brand_name=brand.name,
            brand_code=brand.code,
            logo_url=brand.logo_url,
            onboarding_status="active",
            billing_status="local",
            station_target_count=station_target_count,
            inherit_branding_to_stations=True,
            is_active=True,
        )
        db.add(organization)
    else:
        organization.name = name
        organization.code = code
        organization.description = description
        organization.legal_name = organization.legal_name or name
        organization.brand_catalog_id = brand.id
        organization.brand_name = brand.name
        organization.brand_code = brand.code
        organization.logo_url = organization.logo_url or brand.logo_url
        organization.onboarding_status = "active"
        organization.billing_status = organization.billing_status or "local"
        organization.station_target_count = station_target_count
        organization.inherit_branding_to_stations = True
        organization.is_active = True
    db.commit()
    db.refresh(organization)
    return organization


def ensure_station(db, organization: Organization) -> Station:
    station = (
        db.query(Station)
        .filter(Station.organization_id == organization.id)
        .order_by(Station.id.asc())
        .first()
    )
    if not station:
        station = Station(
            name="check",
            code=organization.code,
            address="Phase 9 local test station",
            city="Local",
            organization_id=organization.id,
            is_head_office=True,
            display_name="check",
            use_organization_branding=True,
            setup_status="active",
            has_shops=True,
            has_pos=True,
            has_tankers=True,
            has_hardware=False,
            allow_meter_adjustments=True,
            is_active=True,
        )
        db.add(station)
        db.commit()
        db.refresh(station)
    else:
        station.name = "check"
        station.display_name = station.display_name or "check"
        station.organization_id = organization.id
        station.is_head_office = True
        station.use_organization_branding = True
        station.setup_status = "active"
        station.has_shops = True
        station.has_pos = True
        station.has_tankers = True
        station.allow_meter_adjustments = True
        station.is_active = True
        db.commit()
    return station


def ensure_named_station(
    db,
    *,
    organization: Organization,
    name: str,
    code: str,
    is_head_office: bool,
    has_pos: bool,
    has_tankers: bool,
    has_hardware: bool,
    allow_meter_adjustments: bool,
) -> Station:
    station = db.query(Station).filter(Station.code == code).first()
    if not station:
        station = Station(
            name=name,
            code=code,
            address=f"{name} Phase 9 local test station",
            city="Local",
            organization_id=organization.id,
            is_head_office=is_head_office,
            display_name=name,
            use_organization_branding=True,
            setup_status="active",
            has_shops=has_pos,
            has_pos=has_pos,
            has_tankers=has_tankers,
            has_hardware=has_hardware,
            allow_meter_adjustments=allow_meter_adjustments,
            is_active=True,
        )
        db.add(station)
    else:
        station.name = name
        station.display_name = name
        station.organization_id = organization.id
        station.is_head_office = is_head_office
        station.use_organization_branding = True
        station.setup_status = "active"
        station.has_shops = has_pos
        station.has_pos = has_pos
        station.has_tankers = has_tankers
        station.has_hardware = has_hardware
        station.allow_meter_adjustments = allow_meter_adjustments
        station.is_active = True
    db.commit()
    db.refresh(station)
    return station


def ensure_user(
    db,
    *,
    username: str,
    password: str,
    full_name: str,
    email: str,
    role: Role,
    organization: Organization,
    station: Station | None,
    scope_level: str,
) -> User:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        user = User(
            full_name=full_name,
            username=username,
            email=email,
            hashed_password=hash_password(password),
            is_active=True,
            role_id=role.id,
            organization_id=organization.id,
            station_id=station.id if station else None,
            scope_level=scope_level,
            is_platform_user=False,
            monthly_salary=0,
            payroll_enabled=True,
        )
        db.add(user)
    else:
        user.full_name = full_name
        user.email = email
        user.hashed_password = hash_password(password)
        user.is_active = True
        user.role_id = role.id
        user.organization_id = organization.id
        user.station_id = station.id if station else None
        user.scope_level = scope_level
        user.is_platform_user = False
    db.commit()
    db.refresh(user)
    return user


def configure_station_modules(
    db,
    station: Station,
    *,
    pos: bool,
    mart: bool,
    tankers: bool,
    hardware: bool,
    meter_adjustments: bool,
) -> None:
    set_station_module(db, station.id, "pos", pos)
    set_station_module(db, station.id, "mart", mart)
    set_station_module(db, station.id, "tanker_operations", tankers)
    set_station_module(db, station.id, "hardware", hardware)
    set_station_module(db, station.id, "meter_adjustments", meter_adjustments)


def ensure_forecourt(db, station: Station) -> None:
    fuel_types = {}
    for name in ["Petrol", "Diesel", "Hi-Octane"]:
        fuel_type = db.query(FuelType).filter(FuelType.name == name).first()
        if not fuel_type:
            fuel_type = FuelType(name=name, description=f"{name} fuel")
            db.add(fuel_type)
            db.commit()
            db.refresh(fuel_type)
        fuel_types[name] = fuel_type

    if db.query(Tank).filter(Tank.station_id == station.id).count() == 0:
        for index, fuel_name in enumerate(fuel_types, start=1):
            db.add(
                Tank(
                    name=f"Tank {index}",
                    code=f"{station.code}-T{index}",
                    capacity=20000,
                    current_volume=10000,
                    low_stock_threshold=2000,
                    station_id=station.id,
                    fuel_type_id=fuel_types[fuel_name].id,
                )
            )
        db.commit()

    if db.query(Dispenser).filter(Dispenser.station_id == station.id).count() == 0:
        for dispenser_number in range(1, 4):
            db.add(
                Dispenser(
                    name=f"Dispenser {dispenser_number}",
                    code=f"{station.code}-D{dispenser_number}",
                    station_id=station.id,
                )
            )
        db.commit()

    tanks = db.query(Tank).filter(Tank.station_id == station.id).order_by(Tank.id).all()
    if os.environ.get("PPMS_RESET_PHASE9_FORECOURT") == "1":
        for tank in tanks:
            tank.capacity = max(float(tank.capacity or 0), 25000.0)
            tank.current_volume = 10000.0
            tank.low_stock_threshold = tank.low_stock_threshold or 2000
        db.commit()
    dispensers = (
        db.query(Dispenser)
        .filter(Dispenser.station_id == station.id)
        .order_by(Dispenser.id)
        .all()
    )
    if db.query(Nozzle).join(Dispenser).filter(Dispenser.station_id == station.id).count() == 0:
        for dispenser_index, dispenser in enumerate(dispensers, start=1):
            tank = tanks[(dispenser_index - 1) % len(tanks)]
            for nozzle_number in range(1, 3):
                meter_reading = 50000.0
                db.add(
                    Nozzle(
                        name=f"Nozzle {dispenser_index}-{nozzle_number}",
                        code=f"{dispenser.code}-N{nozzle_number}",
                        meter_reading=meter_reading,
                        current_segment_start_reading=meter_reading,
                        dispenser_id=dispenser.id,
                        tank_id=tank.id,
                        fuel_type_id=tank.fuel_type_id,
                    )
                )
        db.commit()

    if os.environ.get("PPMS_RESET_PHASE9_FORECOURT") == "1":
        nozzles = db.query(Nozzle).join(Dispenser).filter(Dispenser.station_id == station.id).all()
        for nozzle in nozzles:
            nozzle.meter_reading = 50000.0
            nozzle.current_segment_start_reading = 50000.0
        db.commit()


def ensure_invoice_profile(db, station: Station) -> None:
    invoice_profile = (
        db.query(InvoiceProfile).filter(InvoiceProfile.station_id == station.id).first()
    )
    if invoice_profile:
        return
    db.add(
        InvoiceProfile(
            station_id=station.id,
            business_name=station.name,
            legal_name=station.name,
            invoice_prefix=station.code,
            invoice_number_width=6,
            default_tax_rate=0,
            tax_inclusive=False,
            footer_text="Thank you for your business.",
        )
    )
    db.commit()


def ensure_scope_test_tenants(db, brand: BrandCatalog, roles: dict[str, Role]) -> dict[str, object]:
    multi_org = ensure_named_organization(
        db,
        name="phase9_multi",
        code="PHASE9-MULTI",
        description="Phase 9 multi-station tenant",
        station_target_count=2,
        brand=brand,
    )
    multi_station_a = ensure_named_station(
        db,
        organization=multi_org,
        name="phase9_multi_station_a",
        code="PHASE9-MULTI-A",
        is_head_office=True,
        has_pos=True,
        has_tankers=True,
        has_hardware=False,
        allow_meter_adjustments=True,
    )
    multi_station_b = ensure_named_station(
        db,
        organization=multi_org,
        name="phase9_multi_station_b",
        code="PHASE9-MULTI-B",
        is_head_office=False,
        has_pos=True,
        has_tankers=False,
        has_hardware=False,
        allow_meter_adjustments=True,
    )
    configure_station_modules(
        db,
        multi_station_a,
        pos=True,
        mart=True,
        tankers=True,
        hardware=False,
        meter_adjustments=True,
    )
    configure_station_modules(
        db,
        multi_station_b,
        pos=True,
        mart=True,
        tankers=False,
        hardware=False,
        meter_adjustments=True,
    )
    ensure_user(
        db,
        username="p9_multi",
        password="office123",
        full_name="Phase 9 Multi HeadOffice",
        email="p9.multi@example.com",
        role=roles["HeadOffice"],
        organization=multi_org,
        station=None,
        scope_level="organization",
    )
    ensure_user(
        db,
        username="p9_multi_station_a_admin",
        password="station123",
        full_name="Phase 9 Multi Station A Admin",
        email="p9.multi.a.admin@example.com",
        role=roles["StationAdmin"],
        organization=multi_org,
        station=multi_station_a,
        scope_level="station",
    )
    ensure_user(
        db,
        username="p9_multi_station_b_admin",
        password="station123",
        full_name="Phase 9 Multi Station B Admin",
        email="p9.multi.b.admin@example.com",
        role=roles["StationAdmin"],
        organization=multi_org,
        station=multi_station_b,
        scope_level="station",
    )

    minimal_org = ensure_named_organization(
        db,
        name="phase9_minimal",
        code="PHASE9-MINIMAL",
        description="Phase 9 minimal-module tenant",
        station_target_count=1,
        brand=brand,
    )
    minimal_station = ensure_named_station(
        db,
        organization=minimal_org,
        name="phase9_minimal_station",
        code="PHASE9-MINIMAL-A",
        is_head_office=True,
        has_pos=False,
        has_tankers=False,
        has_hardware=False,
        allow_meter_adjustments=False,
    )
    configure_station_modules(
        db,
        minimal_station,
        pos=False,
        mart=False,
        tankers=False,
        hardware=False,
        meter_adjustments=False,
    )
    ensure_user(
        db,
        username="p9_minimal",
        password="office123",
        full_name="Phase 9 Minimal HeadOffice",
        email="p9.minimal@example.com",
        role=roles["HeadOffice"],
        organization=minimal_org,
        station=None,
        scope_level="organization",
    )
    return {
        "multi_org": multi_org,
        "multi_station_a": multi_station_a,
        "multi_station_b": multi_station_b,
        "minimal_org": minimal_org,
        "minimal_station": minimal_station,
    }


def main() -> None:
    db = SessionLocal()
    try:
        brand = ensure_brand(db)
        roles = {name: ensure_role(db, name) for name in ["HeadOffice", "StationAdmin", "Manager", "Accountant", "Operator"]}
        organization = ensure_organization(db, brand)
        station = ensure_station(db, organization)
        ensure_invoice_profile(db, station)
        ensure_forecourt(db, station)
        configure_station_modules(
            db,
            station,
            pos=True,
            mart=True,
            tankers=True,
            hardware=False,
            meter_adjustments=True,
        )
        scope_tenants = ensure_scope_test_tenants(db, brand, roles)

        ensure_user(
            db,
            username="check",
            password="office123",
            full_name="check",
            email="check@gmail.com",
            role=roles["HeadOffice"],
            organization=organization,
            station=None,
            scope_level="organization",
        )
        ensure_user(
            db,
            username="check_manager",
            password="manager123",
            full_name="Check Manager",
            email="check.manager@example.com",
            role=roles["Manager"],
            organization=organization,
            station=station,
            scope_level="station",
        )
        ensure_user(
            db,
            username="check_accountant",
            password="accountant123",
            full_name="Check Accountant",
            email="check.accountant@example.com",
            role=roles["Accountant"],
            organization=organization,
            station=station,
            scope_level="station",
        )
        ensure_user(
            db,
            username="check_operator",
            password="operator123",
            full_name="Check Operator",
            email="check.operator@example.com",
            role=roles["Operator"],
            organization=organization,
            station=station,
            scope_level="station",
        )

        tank_count = db.query(Tank).filter(Tank.station_id == station.id).count()
        dispenser_count = (
            db.query(Dispenser).filter(Dispenser.station_id == station.id).count()
        )
        nozzle_count = (
            db.query(Nozzle)
            .join(Dispenser)
            .filter(Dispenser.station_id == station.id)
            .count()
        )
        print("Phase 9 tenant ready")
        print(f"organization: {organization.name} ({organization.code}) id={organization.id}")
        print(f"station: {station.name} ({station.code}) id={station.id}")
        print(f"forecourt: tanks={tank_count} dispensers={dispenser_count} nozzles={nozzle_count}")
        print("logins:")
        print("  check / office123")
        print("  check_manager / manager123")
        print("  check_accountant / accountant123")
        print("  check_operator / operator123")
        print("StationAdmin intentionally not created for this one-station tenant.")
        print("Additional scope/module test logins:")
        print("  p9_multi / office123")
        print("  p9_multi_station_a_admin / station123")
        print("  p9_multi_station_b_admin / station123")
        print("  p9_minimal / office123")
        print(
            "scope test tenants: "
            f"multi_org={scope_tenants['multi_org'].id} "
            f"stations={scope_tenants['multi_station_a'].id},{scope_tenants['multi_station_b'].id} "
            f"minimal_org={scope_tenants['minimal_org'].id} "
            f"minimal_station={scope_tenants['minimal_station'].id}"
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()
