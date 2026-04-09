"""
Run once to create the initial platform and tenant users and required setup.
Usage: python seed.py
"""
from pathlib import Path
from datetime import date, time, timedelta

from alembic import command
from alembic.config import Config

from app.core.database import SessionLocal
from app.models.brand_catalog import BrandCatalog
from app.models.organization import Organization
from app.models.organization_module_setting import OrganizationModuleSetting
from app.models.organization_subscription import OrganizationSubscription
from app.core.security import hash_password
from app.models.invoice_profile import InvoiceProfile
from app.models.role import Role
from app.models.station import Station
from app.models.station_module_setting import StationModuleSetting
from app.models.station_shift_template import StationShiftTemplate
from app.models.subscription_plan import SubscriptionPlan
from app.models.auth_session import AuthSession
from app.models.tank_calibration_chart import TankCalibrationChart
from app.models.tank_calibration_chart_line import TankCalibrationChartLine
from app.models.user import User
from app.models.fuel_type import FuelType
from app.models.tank import Tank
from app.models.dispenser import Dispenser
from app.models.employee_profile import EmployeeProfile
from app.models.nozzle import Nozzle
from app.models.payroll_line import PayrollLine
from app.models.payroll_run import PayrollRun
from app.core.permissions import ROLE_CAPABILITY_SUMMARY
from app.services.document_template_seed import seed_default_document_templates


def run_migrations() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    config = Config(str(repo_root / "alembic.ini"))
    config.set_main_option("script_location", str(repo_root / "alembic"))
    command.upgrade(config, "head")


run_migrations()

db = SessionLocal()


def upsert_fuel_type(name: str, description: str | None = None) -> FuelType:
    fuel_type = db.query(FuelType).filter(FuelType.name == name).first()
    if not fuel_type:
        fuel_type = FuelType(name=name, description=description)
        db.add(fuel_type)
        db.commit()
        db.refresh(fuel_type)
        return fuel_type

    fuel_type.description = description
    db.commit()
    db.refresh(fuel_type)
    return fuel_type


def upsert_tank(
    *,
    station_id: int,
    code: str,
    name: str,
    fuel_type_id: int,
    capacity: float,
    current_volume: float,
    low_stock_threshold: float,
) -> Tank:
    tank = db.query(Tank).filter(Tank.code == code).first()
    if not tank:
        tank = Tank(
            station_id=station_id,
            code=code,
            name=name,
            fuel_type_id=fuel_type_id,
            capacity=capacity,
            current_volume=current_volume,
            low_stock_threshold=low_stock_threshold,
        )
        db.add(tank)
        db.commit()
        db.refresh(tank)
        return tank

    tank.station_id = station_id
    tank.name = name
    tank.fuel_type_id = fuel_type_id
    tank.capacity = capacity
    tank.current_volume = current_volume
    tank.low_stock_threshold = low_stock_threshold
    tank.location = None
    db.commit()
    db.refresh(tank)
    return tank


def upsert_dispenser(*, station_id: int, code: str, name: str) -> Dispenser:
    dispenser = db.query(Dispenser).filter(Dispenser.code == code).first()
    if not dispenser:
        dispenser = Dispenser(station_id=station_id, code=code, name=name)
        db.add(dispenser)
        db.commit()
        db.refresh(dispenser)
        return dispenser

    dispenser.station_id = station_id
    dispenser.name = name
    dispenser.location = None
    db.commit()
    db.refresh(dispenser)
    return dispenser


def upsert_nozzle(
    *,
    code: str,
    name: str,
    dispenser_id: int,
    tank_id: int,
    fuel_type_id: int,
) -> Nozzle:
    nozzle = db.query(Nozzle).filter(Nozzle.code == code).first()
    if not nozzle:
        nozzle = Nozzle(
            code=code,
            name=name,
            dispenser_id=dispenser_id,
            tank_id=tank_id,
            fuel_type_id=fuel_type_id,
            meter_reading=0,
            current_segment_start_reading=0,
        )
        db.add(nozzle)
        db.commit()
        db.refresh(nozzle)
        return nozzle

    nozzle.name = name
    nozzle.dispenser_id = dispenser_id
    nozzle.tank_id = tank_id
    nozzle.fuel_type_id = fuel_type_id
    db.commit()
    db.refresh(nozzle)
    return nozzle


def upsert_shift_template(
    *,
    station_id: int,
    name: str,
    start: time,
    end: time,
) -> StationShiftTemplate:
    template = (
        db.query(StationShiftTemplate)
        .filter(
            StationShiftTemplate.station_id == station_id,
            StationShiftTemplate.name == name,
        )
        .first()
    )
    if not template:
        template = StationShiftTemplate(
            station_id=station_id,
            name=name,
            start_time=start,
            end_time=end,
            is_active=True,
        )
        db.add(template)
        db.commit()
        db.refresh(template)
        return template

    template.start_time = start
    template.end_time = end
    template.is_active = True
    db.commit()
    db.refresh(template)
    return template


def ensure_demo_calibration_chart(tank: Tank) -> None:
    existing = (
        db.query(TankCalibrationChart)
        .filter(
            TankCalibrationChart.tank_id == tank.id,
            TankCalibrationChart.is_active.is_(True),
        )
        .first()
    )
    if existing is not None:
        return

    chart = TankCalibrationChart(
        tank_id=tank.id,
        version_no=1,
        source_type="manual",
        notes="Seeded demo chart",
        is_active=True,
    )
    db.add(chart)
    db.commit()
    db.refresh(chart)

    chart_points = [
        (0, 0),
        (500, tank.capacity * 0.25),
        (1000, tank.capacity * 0.50),
        (1500, tank.capacity * 0.75),
        (2000, tank.capacity),
    ]
    for index, (dip_mm, volume_liters) in enumerate(chart_points, start=1):
        db.add(
            TankCalibrationChartLine(
                chart_id=chart.id,
                dip_mm=float(dip_mm),
                volume_liters=float(volume_liters),
                sort_order=index,
            )
        )
    db.commit()

brand_catalog_seed = [
    {
        "code": "CUSTOM",
        "name": "Custom",
        "logo_url": None,
        "primary_color": "#0F766E",
        "sort_order": 0,
    },
    {
        "code": "PSO",
        "name": "PSO",
        "logo_url": "https://psopk.com/assets/images/homepage/logo.png",
        "primary_color": "#00539B",
        "sort_order": 10,
    },
    {
        "code": "HASCOL",
        "name": "Hascol",
        "logo_url": "https://www.hascol.com/wp-content/themes/hascol/img/logo-footer.png",
        "primary_color": "#D62828",
        "sort_order": 20,
    },
    {
        "code": "ATTOCK",
        "name": "Attock",
        "logo_url": "https://www.apl.com.pk/wp-content/uploads/2024/01/attock-logo-300x300.png",
        "primary_color": "#1D4ED8",
        "sort_order": 30,
    },
    {
        "code": "SHELL",
        "name": "Shell",
        "logo_url": None,
        "primary_color": "#F59E0B",
        "sort_order": 40,
    },
    {
        "code": "CALTEX",
        "name": "Caltex",
        "logo_url": None,
        "primary_color": "#DC2626",
        "sort_order": 50,
    },
    {
        "code": "TOTAL",
        "name": "Total",
        "logo_url": None,
        "primary_color": "#2563EB",
        "sort_order": 60,
    },
]

for brand in brand_catalog_seed:
    existing_brand = db.query(BrandCatalog).filter(BrandCatalog.code == brand["code"]).first()
    if not existing_brand:
        db.add(BrandCatalog(**brand, is_active=True))
    else:
        existing_brand.name = brand["name"]
        existing_brand.logo_url = brand["logo_url"]
        existing_brand.primary_color = brand["primary_color"]
        existing_brand.sort_order = brand["sort_order"]
        existing_brand.is_active = True
db.commit()

custom_brand = db.query(BrandCatalog).filter(BrandCatalog.code == "CUSTOM").first()

# Create default roles
roles_data = [
    {"name": "MasterAdmin", "description": ROLE_CAPABILITY_SUMMARY["MasterAdmin"]["governance"]},
    {"name": "StationAdmin", "description": ROLE_CAPABILITY_SUMMARY["StationAdmin"]["governance"]},
    {"name": "HeadOffice", "description": ROLE_CAPABILITY_SUMMARY["HeadOffice"]["governance"]},
    {"name": "Manager", "description": ROLE_CAPABILITY_SUMMARY["Manager"]["governance"]},
    {"name": "Operator", "description": ROLE_CAPABILITY_SUMMARY["Operator"]["governance"]},
    {"name": "Accountant", "description": ROLE_CAPABILITY_SUMMARY["Accountant"]["governance"]},
]

for r in roles_data:
    if not db.query(Role).filter(Role.name == r["name"]).first():
        db.add(Role(**r))
db.commit()

master_admin_role = db.query(Role).filter(Role.name == "MasterAdmin").first()
station_admin_role = db.query(Role).filter(Role.name == "StationAdmin").first()
head_office_role = db.query(Role).filter(Role.name == "HeadOffice").first()
manager_role = db.query(Role).filter(Role.name == "Manager").first()
operator_role = db.query(Role).filter(Role.name == "Operator").first()
accountant_role = db.query(Role).filter(Role.name == "Accountant").first()

# Create default station
organization = db.query(Organization).filter(Organization.code == "DEFAULT").first()
if not organization:
    organization = Organization(
        name="Default Organization",
        code="DEFAULT",
        description="Default head-office organization",
        legal_name="Default Organization Pvt Ltd",
        brand_catalog_id=custom_brand.id if custom_brand else None,
        brand_name="PPMS Demo",
        brand_code="DEMO",
        onboarding_status="active",
        billing_status="trial",
        station_target_count=1,
        inherit_branding_to_stations=True,
        is_active=True,
    )
    db.add(organization)
    db.commit()
    db.refresh(organization)
else:
    organization.legal_name = organization.legal_name or "Default Organization Pvt Ltd"
    organization.brand_name = organization.brand_name or "PPMS Demo"
    organization.brand_code = organization.brand_code or "DEMO"
    organization.onboarding_status = organization.onboarding_status or "active"
    organization.billing_status = organization.billing_status or "trial"
    organization.station_target_count = organization.station_target_count or 1
    organization.inherit_branding_to_stations = True
    db.commit()

station = db.query(Station).filter(Station.code == "HQ").first()
if not station:
    station = Station(
        name="Main Station",
        code="HQ",
        address="Head Office",
        city="Karachi",
        organization_id=organization.id,
        is_head_office=True,
        display_name="Main Station",
        use_organization_branding=True,
        setup_status="active",
        has_shops=True,
        has_pos=True,
        has_tankers=True,
        has_hardware=True,
        allow_meter_adjustments=True,
    )
    db.add(station)
    db.commit()
    db.refresh(station)
elif station.organization_id is None:
    station.organization_id = organization.id
    station.is_head_office = True
    db.commit()

station.display_name = station.display_name or station.name
station.use_organization_branding = True
station.setup_status = station.setup_status or "active"
db.commit()

petrol = upsert_fuel_type("Petrol", "Motor gasoline")
diesel = upsert_fuel_type("Diesel", "High speed diesel")

tank_petrol = upsert_tank(
    station_id=station.id,
    code="HQ-T1",
    name="Petrol Tank 1",
    fuel_type_id=petrol.id,
    capacity=20000,
    current_volume=12000,
    low_stock_threshold=2500,
)
tank_diesel = upsert_tank(
    station_id=station.id,
    code="HQ-T2",
    name="Diesel Tank 1",
    fuel_type_id=diesel.id,
    capacity=20000,
    current_volume=14000,
    low_stock_threshold=2500,
)

disp_1 = upsert_dispenser(station_id=station.id, code="HQ-D1", name="Dispenser 1")
disp_2 = upsert_dispenser(station_id=station.id, code="HQ-D2", name="Dispenser 2")

upsert_nozzle(
    code="HQ-D1-N1",
    name="Nozzle 1",
    dispenser_id=disp_1.id,
    tank_id=tank_petrol.id,
    fuel_type_id=petrol.id,
)
upsert_nozzle(
    code="HQ-D1-N2",
    name="Nozzle 2",
    dispenser_id=disp_1.id,
    tank_id=tank_diesel.id,
    fuel_type_id=diesel.id,
)
upsert_nozzle(
    code="HQ-D2-N1",
    name="Nozzle 3",
    dispenser_id=disp_2.id,
    tank_id=tank_petrol.id,
    fuel_type_id=petrol.id,
)
upsert_nozzle(
    code="HQ-D2-N2",
    name="Nozzle 4",
    dispenser_id=disp_2.id,
    tank_id=tank_diesel.id,
    fuel_type_id=diesel.id,
)

upsert_shift_template(station_id=station.id, name="Morning", start=time(6, 0), end=time(14, 0))
upsert_shift_template(station_id=station.id, name="Evening", start=time(14, 0), end=time(22, 0))
upsert_shift_template(station_id=station.id, name="Night", start=time(22, 0), end=time(6, 0))
ensure_demo_calibration_chart(tank_petrol)
ensure_demo_calibration_chart(tank_diesel)

if not db.query(User).filter(User.username == "masteradmin").first():
    master_admin = User(
        full_name="Razex Master Admin",
        username="masteradmin",
        email="masteradmin@razexsolutions.com",
        hashed_password=hash_password("master123"),
        is_active=True,
        role_id=master_admin_role.id,
        organization_id=None,
        station_id=None,
        scope_level="platform",
        is_platform_user=True,
    )
    db.add(master_admin)
    db.commit()
    print("Master admin created: username=masteradmin  password=master123")
else:
    print("Master admin already exists.")

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

# Remove legacy generic admin login/role from older local databases.
legacy_admin = db.query(User).filter(User.username == "admin").first()
if legacy_admin:
    db.query(AuthSession).filter(AuthSession.user_id == legacy_admin.id).delete(synchronize_session=False)
    db.delete(legacy_admin)
    db.commit()
    print("Legacy admin user removed.")

legacy_admin_role = db.query(Role).filter(Role.name == "Admin").first()
if legacy_admin_role and not db.query(User).filter(User.role_id == legacy_admin_role.id).first():
    db.delete(legacy_admin_role)
    db.commit()
    print("Legacy Admin role removed.")

demo_users = [
    {
        "username": "headoffice",
        "password": "office123",
        "full_name": "Head Office Reviewer",
        "email": "headoffice@ppms.com",
        "role": head_office_role,
        "organization_id": organization.id,
        "station_id": None,
        "scope_level": "organization",
        "is_platform_user": False,
    },
    {
        "username": "stationadmin",
        "password": "station123",
        "full_name": "Station Administrator",
        "email": "stationadmin@ppms.com",
        "role": station_admin_role,
        "organization_id": organization.id,
        "station_id": station.id,
        "scope_level": "station",
        "is_platform_user": False,
    },
    {
        "username": "manager",
        "password": "manager123",
        "full_name": "Station Manager",
        "email": "manager@ppms.com",
        "role": manager_role,
        "organization_id": organization.id,
        "station_id": station.id,
        "scope_level": "station",
        "is_platform_user": False,
    },
    {
        "username": "operator",
        "password": "operator123",
        "full_name": "Forecourt Operator",
        "email": "operator@ppms.com",
        "role": operator_role,
        "organization_id": organization.id,
        "station_id": station.id,
        "scope_level": "station",
        "is_platform_user": False,
    },
    {
        "username": "accountant",
        "password": "accountant123",
        "full_name": "Station Accountant",
        "email": "accountant@ppms.com",
        "role": accountant_role,
        "organization_id": organization.id,
        "station_id": station.id,
        "scope_level": "station",
        "is_platform_user": False,
    },
]

for demo_user in demo_users:
    existing_user = db.query(User).filter(User.username == demo_user["username"]).first()
    if not existing_user:
        db.add(
            User(
                full_name=demo_user["full_name"],
                username=demo_user["username"],
                email=demo_user["email"],
                hashed_password=hash_password(demo_user["password"]),
                is_active=True,
                role_id=demo_user["role"].id,
                organization_id=demo_user["organization_id"],
                station_id=demo_user["station_id"],
                scope_level=demo_user["scope_level"],
                is_platform_user=demo_user["is_platform_user"],
            )
        )
        db.commit()
        print(
            f"Demo user created: username={demo_user['username']}  password={demo_user['password']}"
        )
    else:
        existing_user.full_name = demo_user["full_name"]
        existing_user.email = demo_user["email"]
        existing_user.role_id = demo_user["role"].id
        existing_user.organization_id = demo_user["organization_id"]
        existing_user.station_id = demo_user["station_id"]
        existing_user.scope_level = demo_user["scope_level"]
        existing_user.is_platform_user = demo_user["is_platform_user"]
        existing_user.is_active = True
        db.commit()


demo_profile_blueprints = [
    {
        "username": "stationadmin",
        "staff_type": "station_admin",
        "staff_title": "Station Admin",
        "employee_code": "EMP-SA-001",
        "monthly_salary": 140000.0,
    },
    {
        "username": "manager",
        "staff_type": "manager",
        "staff_title": "Shift Manager",
        "employee_code": "EMP-MG-001",
        "monthly_salary": 90000.0,
    },
    {
        "username": "operator",
        "staff_type": "operator",
        "staff_title": "Pump Operator",
        "employee_code": "EMP-OP-001",
        "monthly_salary": 52000.0,
    },
    {
        "username": "accountant",
        "staff_type": "accountant",
        "staff_title": "Accountant",
        "employee_code": "EMP-AC-001",
        "monthly_salary": 80000.0,
    },
]

for blueprint in demo_profile_blueprints:
    user = db.query(User).filter(User.username == blueprint["username"]).first()
    if user is None:
        continue
    profile = db.query(EmployeeProfile).filter(EmployeeProfile.linked_user_id == user.id).first()
    if profile is None:
        profile = EmployeeProfile(
            organization_id=organization.id,
            station_id=user.station_id or station.id,
            linked_user_id=user.id,
            full_name=user.full_name,
            staff_type=blueprint["staff_type"],
            staff_title=blueprint["staff_title"],
            employee_code=blueprint["employee_code"],
            phone=user.phone,
            is_active=True,
            payroll_enabled=True,
            monthly_salary=blueprint["monthly_salary"],
            can_login=True,
        )
        db.add(profile)
    else:
        profile.organization_id = organization.id
        profile.station_id = user.station_id or station.id
        profile.full_name = user.full_name
        profile.staff_type = blueprint["staff_type"]
        profile.staff_title = blueprint["staff_title"]
        profile.employee_code = blueprint["employee_code"]
        profile.phone = user.phone
        profile.is_active = True
        profile.payroll_enabled = True
        profile.monthly_salary = blueprint["monthly_salary"]
        profile.can_login = True
    user.monthly_salary = blueprint["monthly_salary"]
    user.payroll_enabled = True
    db.commit()

today = date.today()
current_month_start = today.replace(day=1)
previous_month_end = current_month_start - timedelta(days=1)
previous_month_start = previous_month_end.replace(day=1)

demo_payroll_run = (
    db.query(PayrollRun)
    .filter(
        PayrollRun.station_id == station.id,
        PayrollRun.period_start == previous_month_start,
        PayrollRun.period_end == previous_month_end,
    )
    .first()
)
if demo_payroll_run is None:
    accountant_user = db.query(User).filter(User.username == "accountant").first()
    demo_payroll_run = PayrollRun(
        station_id=station.id,
        period_start=previous_month_start,
        period_end=previous_month_end,
        status="finalized",
        total_staff=0,
        total_gross_amount=0.0,
        total_deductions=0.0,
        total_net_amount=0.0,
        notes="Demo payroll run for operator self-service checks",
        generated_by_user_id=accountant_user.id if accountant_user is not None else 1,
        finalized_by_user_id=accountant_user.id if accountant_user is not None else 1,
    )
    db.add(demo_payroll_run)
    db.commit()
    db.refresh(demo_payroll_run)

payroll_line_blueprints = {
    "stationadmin": {"additions": 8000.0, "attendance_deductions": 0.0, "other_deductions": 0.0},
    "manager": {"additions": 6000.0, "attendance_deductions": 1500.0, "other_deductions": 500.0},
    "operator": {"additions": 2500.0, "attendance_deductions": 500.0, "other_deductions": 0.0},
    "accountant": {"additions": 4000.0, "attendance_deductions": 0.0, "other_deductions": 1000.0},
}

gross_total = 0.0
deductions_total = 0.0
net_total = 0.0
staff_count = 0
for username, figures in payroll_line_blueprints.items():
    user = db.query(User).filter(User.username == username).first()
    profile = db.query(EmployeeProfile).filter(EmployeeProfile.linked_user_id == user.id).first() if user is not None else None
    if user is None or profile is None:
        continue

    monthly_salary = float(profile.monthly_salary)
    additions = float(figures["additions"])
    attendance_deductions = float(figures["attendance_deductions"])
    adjustment_deductions = float(figures["other_deductions"])
    total_deductions = attendance_deductions + adjustment_deductions
    gross_amount = monthly_salary + additions
    net_amount = gross_amount - total_deductions

    line = (
        db.query(PayrollLine)
        .filter(
            PayrollLine.payroll_run_id == demo_payroll_run.id,
            PayrollLine.user_id == user.id,
        )
        .first()
    )
    if line is None:
        line = PayrollLine(
            payroll_run_id=demo_payroll_run.id,
            user_id=user.id,
            employee_profile_id=profile.id,
        )
        db.add(line)

    line.employee_profile_id = profile.id
    line.present_days = 26
    line.leave_days = 2
    line.absent_days = 1 if username == "manager" else 0
    line.payable_days = 29 if username == "manager" else 30
    line.monthly_salary = monthly_salary
    line.gross_amount = gross_amount
    line.attendance_deductions = attendance_deductions
    line.adjustment_additions = additions
    line.adjustment_deductions = adjustment_deductions
    line.deductions = total_deductions
    line.net_amount = net_amount

    gross_total += gross_amount
    deductions_total += total_deductions
    net_total += net_amount
    staff_count += 1

demo_payroll_run.status = "finalized"
demo_payroll_run.total_staff = staff_count
demo_payroll_run.total_gross_amount = gross_total
demo_payroll_run.total_deductions = deductions_total
demo_payroll_run.total_net_amount = net_total
db.commit()

db.close()
print("Seed complete.")
