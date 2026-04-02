import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = PROJECT_ROOT / "ppms"
if str(APP_ROOT) not in sys.path:
    sys.path.insert(0, str(APP_ROOT))

from app.core.database import Base, get_db  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.main import app  # noqa: E402
from app.models.customer import Customer  # noqa: E402
from app.models.dispenser import Dispenser  # noqa: E402
from app.models.fuel_type import FuelType  # noqa: E402
from app.models.nozzle import Nozzle  # noqa: E402
from app.models.organization import Organization  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.shift import Shift  # noqa: E402
from app.models.station import Station  # noqa: E402
from app.models.supplier import Supplier  # noqa: E402
from app.models.tank import Tank  # noqa: E402
from app.models.user import User  # noqa: E402


@pytest.fixture()
def client(tmp_path):
    db_path = tmp_path / "test_ppms.db"
    engine = create_engine(
        f"sqlite:///{db_path}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client, testing_session_local

    app.dependency_overrides.clear()


def seed_base_data(session_local):
    db = session_local()
    try:
        admin_role = Role(name="Admin", description="Full access")
        manager_role = Role(name="Manager", description="Station management")
        accountant_role = Role(name="Accountant", description="Financial operations")
        operator_role = Role(name="Operator", description="Daily operations")
        db.add_all([admin_role, manager_role, accountant_role, operator_role])
        db.flush()

        organization = Organization(
            name="Org A",
            code="ORG-A",
            description="Primary organization",
            is_active=True,
        )
        db.add(organization)
        db.flush()

        station_a = Station(
            name="Station A",
            code="STA",
            address="Addr A",
            city="City A",
            organization_id=organization.id,
            is_head_office=True,
        )
        station_b = Station(
            name="Station B",
            code="STB",
            address="Addr B",
            city="City B",
            organization_id=organization.id,
            is_head_office=False,
        )
        db.add_all([station_a, station_b])
        db.flush()

        admin = User(
            full_name="Admin User",
            username="admin",
            email="admin@example.com",
            hashed_password=hash_password("admin123"),
            is_active=True,
            role_id=admin_role.id,
            station_id=station_a.id,
        )
        operator = User(
            full_name="Operator User",
            username="operator",
            email="operator@example.com",
            hashed_password=hash_password("operator123"),
            is_active=True,
            role_id=operator_role.id,
            station_id=station_a.id,
        )
        manager = User(
            full_name="Manager User",
            username="manager",
            email="manager@example.com",
            hashed_password=hash_password("manager123"),
            is_active=True,
            role_id=manager_role.id,
            station_id=station_a.id,
        )
        accountant = User(
            full_name="Accountant User",
            username="accountant",
            email="accountant@example.com",
            hashed_password=hash_password("accountant123"),
            is_active=True,
            role_id=accountant_role.id,
            station_id=station_a.id,
        )
        db.add_all([admin, operator, manager, accountant])
        db.flush()

        fuel_type = FuelType(name="Petrol", description="Fuel")
        db.add(fuel_type)
        db.flush()

        tank = Tank(
            name="Tank A",
            code="TANK-A",
            capacity=1000,
            current_volume=100,
            low_stock_threshold=20,
            location="Underground",
            station_id=station_a.id,
            fuel_type_id=fuel_type.id,
        )
        db.add(tank)
        db.flush()

        dispenser = Dispenser(
            name="Dispenser A",
            code="DISP-A",
            location="Front",
            station_id=station_a.id,
        )
        db.add(dispenser)
        db.flush()

        nozzle = Nozzle(
            name="Nozzle A",
            code="NOZ-A",
            meter_reading=1000,
            dispenser_id=dispenser.id,
            tank_id=tank.id,
            fuel_type_id=fuel_type.id,
        )
        db.add(nozzle)

        customer = Customer(
            name="Customer A",
            code="CUST-A",
            customer_type="company",
            phone="123",
            address="Addr",
            credit_limit=500,
            outstanding_balance=0,
            station_id=station_a.id,
        )
        db.add(customer)

        supplier = Supplier(name="Supplier A", code="SUP-A", phone="123", address="Addr", payable_balance=0)
        db.add(supplier)

        foreign_shift = Shift(
            station_id=station_b.id,
            user_id=admin.id,
            status="open",
            initial_cash=0,
            expected_cash=0,
        )
        db.add(foreign_shift)

        db.commit()
        return {
            "organization_id": organization.id,
            "station_a_id": station_a.id,
            "station_b_id": station_b.id,
            "fuel_type_id": fuel_type.id,
            "tank_id": tank.id,
            "nozzle_id": nozzle.id,
            "customer_id": customer.id,
            "foreign_shift_id": foreign_shift.id,
        }
    finally:
        db.close()


def login(client: TestClient, username: str, password: str) -> dict[str, str]:
    response = client.post("/auth/login", json={"username": username, "password": password})
    assert response.status_code == 200, response.text
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
