"""
Run once to create the initial admin user and required setup.
Usage: python seed.py
"""
from pathlib import Path

from alembic import command
from alembic.config import Config

from app.core.database import SessionLocal
from app.models.organization import Organization
from app.models.organization_module_setting import OrganizationModuleSetting
from app.models.organization_subscription import OrganizationSubscription
from app.core.security import hash_password
from app.models.invoice_profile import InvoiceProfile
from app.models.role import Role
from app.models.station import Station
from app.models.station_module_setting import StationModuleSetting
from app.models.subscription_plan import SubscriptionPlan
from app.models.user import User
from app.services.document_template_seed import seed_default_document_templates


def run_migrations() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    config = Config(str(repo_root / "alembic.ini"))
    config.set_main_option("script_location", str(repo_root / "alembic"))
    command.upgrade(config, "head")


run_migrations()

db = SessionLocal()

# Create default roles
roles_data = [
    {"name": "Admin", "description": "Full system access"},
    {"name": "HeadOffice", "description": "Organization-wide read access"},
    {"name": "Manager", "description": "Station management access"},
    {"name": "Operator", "description": "Daily operations access"},
    {"name": "Accountant", "description": "Financial access only"},
]

for r in roles_data:
    if not db.query(Role).filter(Role.name == r["name"]).first():
        db.add(Role(**r))
db.commit()

admin_role = db.query(Role).filter(Role.name == "Admin").first()

# Create default station
organization = db.query(Organization).filter(Organization.code == "DEFAULT").first()
if not organization:
    organization = Organization(
        name="Default Organization",
        code="DEFAULT",
        description="Default head-office organization",
        is_active=True,
    )
    db.add(organization)
    db.commit()
    db.refresh(organization)

station = db.query(Station).filter(Station.code == "HQ").first()
if not station:
    station = Station(
        name="Main Station",
        code="HQ",
        address="Head Office",
        city="Karachi",
        organization_id=organization.id,
        is_head_office=True,
    )
    db.add(station)
    db.commit()
    db.refresh(station)
elif station.organization_id is None:
    station.organization_id = organization.id
    station.is_head_office = True
    db.commit()

invoice_profile = db.query(InvoiceProfile).filter(InvoiceProfile.station_id == station.id).first()
if not invoice_profile:
    invoice_profile = InvoiceProfile(
        station_id=station.id,
        business_name=station.name,
        legal_name=station.name,
        invoice_prefix=station.code,
        invoice_number_width=6,
        default_tax_rate=0,
        tax_inclusive=False,
        footer_text="Thank you for your business.",
    )
    db.add(invoice_profile)
    db.commit()
    db.refresh(invoice_profile)

tanker_module = db.query(StationModuleSetting).filter(
    StationModuleSetting.station_id == station.id,
    StationModuleSetting.module_name == "tanker_operations",
).first()
if not tanker_module:
    db.add(StationModuleSetting(station_id=station.id, module_name="tanker_operations", is_enabled=True))
    db.commit()

meter_adjustment_module = db.query(StationModuleSetting).filter(
    StationModuleSetting.station_id == station.id,
    StationModuleSetting.module_name == "meter_adjustments",
).first()
if not meter_adjustment_module:
    db.add(StationModuleSetting(station_id=station.id, module_name="meter_adjustments", is_enabled=True))
    db.commit()

starter_plan = db.query(SubscriptionPlan).filter(SubscriptionPlan.code == "LOCAL-STARTER").first()
if not starter_plan:
    starter_plan = SubscriptionPlan(
        name="Local Starter",
        code="LOCAL-STARTER",
        description="Default local-first plan with SaaS foundation kept optional.",
        monthly_price=0,
        yearly_price=0,
        max_stations=3,
        max_users=25,
        feature_summary="Core PPMS backend, organization controls, optional SaaS toggles",
        is_active=True,
        is_default=True,
    )
    db.add(starter_plan)
    db.commit()
    db.refresh(starter_plan)

organization_subscription = (
    db.query(OrganizationSubscription)
    .filter(OrganizationSubscription.organization_id == organization.id)
    .first()
)
if not organization_subscription:
    db.add(
        OrganizationSubscription(
            organization_id=organization.id,
            plan_id=starter_plan.id,
            status="local",
            billing_cycle="monthly",
            auto_renew=False,
            notes="Default local-first organization subscription",
        )
    )
    db.commit()

for module_name, is_enabled in [
    ("saas_billing", False),
    ("customer_portal", False),
    ("self_service_onboarding", False),
]:
    existing_org_module = (
        db.query(OrganizationModuleSetting)
        .filter(
            OrganizationModuleSetting.organization_id == organization.id,
            OrganizationModuleSetting.module_name == module_name,
        )
        .first()
    )
    if not existing_org_module:
        db.add(
            OrganizationModuleSetting(
                organization_id=organization.id,
                module_name=module_name,
                is_enabled=is_enabled,
            )
        )
        db.commit()

seed_default_document_templates(db, station)

# Create admin user
if not db.query(User).filter(User.username == "admin").first():
    admin = User(
        full_name="System Admin",
        username="admin",
        email="admin@ppms.com",
        hashed_password=hash_password("admin123"),
        is_active=True,
        role_id=admin_role.id,
        station_id=station.id,
    )
    db.add(admin)
    db.commit()
    print("Admin user created: username=admin  password=admin123")
else:
    print("Admin user already exists.")

db.close()
print("Seed complete.")
