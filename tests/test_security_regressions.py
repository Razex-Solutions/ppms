import sys
from datetime import date
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
from app.main import app, create_app  # noqa: E402
from app.models.customer import Customer  # noqa: E402
from app.models.expense import Expense  # noqa: E402
from app.models.dispenser import Dispenser  # noqa: E402
from app.models.fuel_type import FuelType  # noqa: E402
from app.models.hardware_device import HardwareDevice  # noqa: E402
from app.models.nozzle import Nozzle  # noqa: E402
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

        station_a = Station(name="Station A", code="STA", address="Addr A", city="City A")
        station_b = Station(name="Station B", code="STB", address="Addr B", city="City B")
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


def test_non_admin_cannot_manage_users(client):
    test_client, session_local = client
    seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    response = test_client.get("/users/", headers=headers)

    assert response.status_code == 403
    assert response.json()["detail"] == "Admin access required"


def test_shift_details_are_scoped_by_station(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    response = test_client.get(f"/shifts/{data['foreign_shift_id']}", headers=headers)

    assert response.status_code == 403
    assert response.json()["detail"] == "Not authorized for this shift"


def test_supplier_endpoints_no_longer_reference_missing_station_fields(client):
    test_client, session_local = client
    seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    response = test_client.get("/suppliers/", headers=headers)

    assert response.status_code == 200
    assert len(response.json()) == 1


def test_fuel_sale_rejects_cross_station_or_invalid_stock(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    wrong_station_response = test_client.post(
        "/fuel-sales/",
        headers=headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_b_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 1010,
            "rate_per_liter": 270,
            "sale_type": "cash",
        },
    )

    assert wrong_station_response.status_code == 403

    stock_response = test_client.post(
        "/fuel-sales/",
        headers=headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 1200,
            "rate_per_liter": 270,
            "sale_type": "cash",
        },
    )

    assert stock_response.status_code == 400
    assert stock_response.json()["detail"] == "Insufficient tank stock for this sale"


def test_fuel_sale_can_be_fetched_and_reversed_safely(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    create_response = test_client.post(
        "/fuel-sales/",
        headers=headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "customer_id": data["customer_id"],
            "closing_meter": 1010,
            "rate_per_liter": 10,
            "sale_type": "credit",
        },
    )

    assert create_response.status_code == 200, create_response.text
    sale = create_response.json()

    get_response = test_client.get(f"/fuel-sales/{sale['id']}", headers=headers)
    assert get_response.status_code == 200
    assert get_response.json()["id"] == sale["id"]

    reverse_response = test_client.post(f"/fuel-sales/{sale['id']}/reverse", headers=headers)
    assert reverse_response.status_code == 200, reverse_response.text
    assert reverse_response.json()["is_reversed"] is True

    db = session_local()
    try:
        tank = db.query(Tank).filter(Tank.id == data["tank_id"]).first()
        nozzle = db.query(Nozzle).filter(Nozzle.id == data["nozzle_id"]).first()
        customer = db.query(Customer).filter(Customer.id == data["customer_id"]).first()
        assert tank.current_volume == 100
        assert nozzle.meter_reading == 1000
        assert customer.outstanding_balance == 0
    finally:
        db.close()


def test_customer_and_supplier_payments_have_detail_and_reverse_flows(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    db = session_local()
    try:
        customer = db.query(Customer).filter(Customer.id == data["customer_id"]).first()
        supplier = db.query(Supplier).filter(Supplier.code == "SUP-A").first()
        customer.outstanding_balance = 80
        supplier.payable_balance = 90
        db.commit()
        supplier_id = supplier.id
    finally:
        db.close()

    customer_payment = test_client.post(
        "/customer-payments/",
        headers=headers,
        json={
            "customer_id": data["customer_id"],
            "station_id": data["station_a_id"],
            "amount": 30,
            "payment_method": "cash",
        },
    )
    assert customer_payment.status_code == 200, customer_payment.text
    customer_payment_id = customer_payment.json()["id"]

    customer_payment_detail = test_client.get(f"/customer-payments/{customer_payment_id}", headers=headers)
    assert customer_payment_detail.status_code == 200

    customer_payment_reverse = test_client.post(f"/customer-payments/{customer_payment_id}/reverse", headers=headers)
    assert customer_payment_reverse.status_code == 200
    assert customer_payment_reverse.json()["is_reversed"] is True

    supplier_payment = test_client.post(
        "/supplier-payments/",
        headers=headers,
        json={
            "supplier_id": supplier_id,
            "station_id": data["station_a_id"],
            "amount": 40,
            "payment_method": "cash",
        },
    )
    assert supplier_payment.status_code == 200, supplier_payment.text
    supplier_payment_id = supplier_payment.json()["id"]

    supplier_payment_detail = test_client.get(f"/supplier-payments/{supplier_payment_id}", headers=headers)
    assert supplier_payment_detail.status_code == 200

    supplier_payment_reverse = test_client.post(f"/supplier-payments/{supplier_payment_id}/reverse", headers=headers)
    assert supplier_payment_reverse.status_code == 200
    assert supplier_payment_reverse.json()["is_reversed"] is True


def test_module_toggle_can_disable_routes(tmp_path):
    db_path = tmp_path / "toggle_test.db"
    engine = create_engine(
        f"sqlite:///{db_path}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    module_app = create_app(enabled_modules="auth,customers")

    def override_get_db():
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    module_app.dependency_overrides[get_db] = override_get_db

    with TestClient(module_app) as test_client:
        health = test_client.get("/health")
        assert health.status_code == 200
        assert "customers" in health.json()["enabled_modules"]
        assert "expenses" not in health.json()["enabled_modules"]

        disabled = test_client.get("/expenses/")
        assert disabled.status_code == 404

    module_app.dependency_overrides.clear()


def test_operator_cannot_read_other_station_customer_or_expense(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    db = session_local()
    try:
        foreign_customer = Customer(
            name="Customer B",
            code="CUST-B",
            customer_type="company",
            phone="456",
            address="Addr B",
            credit_limit=100,
            outstanding_balance=0,
            station_id=data["station_b_id"],
        )
        db.add(foreign_customer)
        db.flush()

        foreign_expense = Expense(
            title="Foreign Expense",
            category="Ops",
            amount=20,
            notes="Other station",
            station_id=data["station_b_id"],
        )
        db.add(foreign_expense)
        db.commit()
        foreign_customer_id = foreign_customer.id
        foreign_expense_id = foreign_expense.id
    finally:
        db.close()

    customer_response = test_client.get(f"/customers/{foreign_customer_id}", headers=headers)
    assert customer_response.status_code == 403

    expense_response = test_client.get(f"/expenses/{foreign_expense_id}", headers=headers)
    assert expense_response.status_code == 403


def test_purchase_reverse_updates_payables_dashboard(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    db = session_local()
    try:
        supplier = db.query(Supplier).filter(Supplier.code == "SUP-A").first()
        supplier_id = supplier.id
    finally:
        db.close()

    purchase_response = test_client.post(
        "/purchases/",
        headers=headers,
        json={
            "supplier_id": supplier_id,
            "tank_id": data["tank_id"],
            "fuel_type_id": data["fuel_type_id"],
            "quantity": 20,
            "rate_per_liter": 5,
        },
    )
    assert purchase_response.status_code == 200, purchase_response.text
    purchase_id = purchase_response.json()["id"]

    dashboard_before = test_client.get("/dashboard/", headers=headers)
    assert dashboard_before.status_code == 200
    assert dashboard_before.json()["payables"] == 100

    reverse_response = test_client.post(f"/purchases/{purchase_id}/reverse", headers=headers)
    assert reverse_response.status_code == 200
    assert reverse_response.json()["is_reversed"] is True

    dashboard_after = test_client.get("/dashboard/", headers=headers)
    assert dashboard_after.status_code == 200
    assert dashboard_after.json()["payables"] == 0


def test_shift_close_ignores_reversed_sales(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    headers = login(test_client, "operator", "operator123")

    shift_response = test_client.post(
        "/shifts/",
        headers=headers,
        json={"station_id": data["station_a_id"], "initial_cash": 50},
    )
    assert shift_response.status_code == 200, shift_response.text
    shift_id = shift_response.json()["id"]

    sale_response = test_client.post(
        "/fuel-sales/",
        headers=headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 1005,
            "rate_per_liter": 10,
            "sale_type": "cash",
            "shift_id": shift_id,
        },
    )
    assert sale_response.status_code == 200, sale_response.text
    sale_id = sale_response.json()["id"]

    reverse_response = test_client.post(f"/fuel-sales/{sale_id}/reverse", headers=headers)
    assert reverse_response.status_code == 200

    close_response = test_client.post(
        f"/shifts/{shift_id}/close",
        headers=headers,
        json={"actual_cash_collected": 50},
    )
    assert close_response.status_code == 200, close_response.text
    closed_shift = close_response.json()
    assert closed_shift["total_sales_cash"] == 0
    assert closed_shift["expected_cash"] == 50
    assert closed_shift["difference"] == 0


def test_master_data_delete_is_blocked_when_history_exists(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    admin_headers = login(test_client, "admin", "admin123")
    operator_headers = login(test_client, "operator", "operator123")

    sale_response = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "customer_id": data["customer_id"],
            "closing_meter": 1002,
            "rate_per_liter": 10,
            "sale_type": "credit",
        },
    )
    assert sale_response.status_code == 200, sale_response.text

    db = session_local()
    try:
        supplier = db.query(Supplier).filter(Supplier.code == "SUP-A").first()
        supplier.payable_balance = 50
        db.commit()
        supplier_id = supplier.id
    finally:
        db.close()

    supplier_payment_response = test_client.post(
        "/supplier-payments/",
        headers=admin_headers,
        json={
            "supplier_id": supplier_id,
            "station_id": data["station_a_id"],
            "amount": 20,
            "payment_method": "cash",
        },
    )
    assert supplier_payment_response.status_code == 200, supplier_payment_response.text

    customer_delete = test_client.delete(f"/customers/{data['customer_id']}", headers=operator_headers)
    assert customer_delete.status_code == 400

    supplier_delete = test_client.delete(f"/suppliers/{supplier_id}", headers=admin_headers)
    assert supplier_delete.status_code == 400

    tank_delete = test_client.delete(f"/tanks/{data['tank_id']}", headers=operator_headers)
    assert tank_delete.status_code == 400

    fuel_type_delete = test_client.delete(f"/fuel-types/{data['fuel_type_id']}", headers=admin_headers)
    assert fuel_type_delete.status_code == 400

    station_delete = test_client.delete(f"/stations/{data['station_a_id']}", headers=admin_headers)
    assert station_delete.status_code == 400


def test_pos_product_and_sale_flow_with_reverse_and_module_toggle(client, tmp_path):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")

    product_response = test_client.post(
        "/pos-products/",
        headers=operator_headers,
        json={
            "name": "Engine Oil",
            "code": "POS-001",
            "category": "Lubricants",
            "module": "mart",
            "price": 25,
            "stock_quantity": 10,
            "track_inventory": True,
            "station_id": data["station_a_id"],
        },
    )
    assert product_response.status_code == 200, product_response.text
    product_id = product_response.json()["id"]

    sale_response = test_client.post(
        "/pos-sales/",
        headers=operator_headers,
        json={
            "station_id": data["station_a_id"],
            "module": "mart",
            "payment_method": "cash",
            "items": [{"product_id": product_id, "quantity": 2}],
        },
    )
    assert sale_response.status_code == 200, sale_response.text
    sale = sale_response.json()
    assert sale["total_amount"] == 50
    assert len(sale["items"]) == 1

    db = session_local()
    try:
        from app.models.pos_product import POSProduct

        product = db.query(POSProduct).filter(POSProduct.id == product_id).first()
        assert product.stock_quantity == 8
    finally:
        db.close()

    reverse_response = test_client.post(f"/pos-sales/{sale['id']}/reverse", headers=operator_headers)
    assert reverse_response.status_code == 200, reverse_response.text
    assert reverse_response.json()["is_reversed"] is True

    db = session_local()
    try:
        from app.models.pos_product import POSProduct

        product = db.query(POSProduct).filter(POSProduct.id == product_id).first()
        assert product.stock_quantity == 10
    finally:
        db.close()

    delete_response = test_client.delete(f"/pos-products/{product_id}", headers=operator_headers)
    assert delete_response.status_code == 400

    toggle_db_path = tmp_path / "pos_toggle.db"
    engine = create_engine(
        f"sqlite:///{toggle_db_path}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    pos_only_app = create_app(enabled_modules="auth,pos_products,pos_sales")

    def override_get_db():
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    pos_only_app.dependency_overrides[get_db] = override_get_db

    with TestClient(pos_only_app) as pos_client:
        health = pos_client.get("/health")
        assert health.status_code == 200
        assert "pos_products" in health.json()["enabled_modules"]
        assert "customers" not in health.json()["enabled_modules"]
        disabled = pos_client.get("/customers/")
        assert disabled.status_code == 404

    pos_only_app.dependency_overrides.clear()


def test_hardware_device_and_simulator_flow(client, tmp_path):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")

    dispenser_device_response = test_client.post(
        "/hardware/devices",
        headers=manager_headers,
        json={
            "name": "Wayne Simulator",
            "code": "HW-DISP-001",
            "device_type": "dispenser",
            "integration_mode": "simulated",
            "status": "offline",
            "station_id": data["station_a_id"],
            "dispenser_id": 1,
        },
    )
    assert dispenser_device_response.status_code == 200, dispenser_device_response.text
    dispenser_device_id = dispenser_device_response.json()["id"]

    tank_probe_response = test_client.post(
        "/hardware/devices",
        headers=manager_headers,
        json={
            "name": "Probe Simulator",
            "code": "HW-TANK-001",
            "device_type": "tank_probe",
            "integration_mode": "simulated",
            "status": "offline",
            "station_id": data["station_a_id"],
            "tank_id": data["tank_id"],
        },
    )
    assert tank_probe_response.status_code == 200, tank_probe_response.text
    tank_probe_id = tank_probe_response.json()["id"]

    dispenser_event_response = test_client.post(
        "/hardware/simulate/dispenser-reading",
        headers=manager_headers,
        json={
            "device_id": dispenser_device_id,
            "nozzle_id": data["nozzle_id"],
            "meter_reading": 1005,
            "volume": 5,
        },
    )
    assert dispenser_event_response.status_code == 200, dispenser_event_response.text
    assert dispenser_event_response.json()["event_type"] == "dispenser_reading"

    tank_event_response = test_client.post(
        "/hardware/simulate/tank-probe-reading",
        headers=manager_headers,
        json={
            "device_id": tank_probe_id,
            "volume": 95,
            "temperature": 23.5,
        },
    )
    assert tank_event_response.status_code == 200, tank_event_response.text
    assert tank_event_response.json()["event_type"] == "tank_probe_reading"

    events_response = test_client.get("/hardware/events", headers=manager_headers)
    assert events_response.status_code == 200
    assert len(events_response.json()) == 2

    db = session_local()
    try:
        device = db.query(HardwareDevice).filter(HardwareDevice.id == dispenser_device_id).first()
        assert device.status == "online"
        assert device.last_seen_at is not None
    finally:
        db.close()

    delete_response = test_client.delete(f"/hardware/devices/{dispenser_device_id}", headers=manager_headers)
    assert delete_response.status_code == 400

    toggle_db_path = tmp_path / "hardware_toggle.db"
    engine = create_engine(
        f"sqlite:///{toggle_db_path}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    hardware_only_app = create_app(enabled_modules="auth,hardware")

    def override_get_db():
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    hardware_only_app.dependency_overrides[get_db] = override_get_db

    with TestClient(hardware_only_app) as hardware_client:
        health = hardware_client.get("/health")
        assert health.status_code == 200
        assert "hardware" in health.json()["enabled_modules"]
        assert "customers" not in health.json()["enabled_modules"]
        disabled = hardware_client.get("/customers/")
        assert disabled.status_code == 404

    hardware_only_app.dependency_overrides.clear()


def test_operator_cannot_access_foreign_hardware_device(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")

    db = session_local()
    try:
        foreign_dispenser = Dispenser(
            name="Dispenser B",
            code="DISP-B",
            location="Back",
            station_id=data["station_b_id"],
        )
        db.add(foreign_dispenser)
        db.flush()

        foreign_device = HardwareDevice(
            name="Foreign Hardware",
            code="HW-FOR-001",
            device_type="dispenser",
            integration_mode="simulated",
            status="offline",
            station_id=data["station_b_id"],
            dispenser_id=foreign_dispenser.id,
        )
        db.add(foreign_device)
        db.commit()
        foreign_device_id = foreign_device.id
    finally:
        db.close()

    response = test_client.get(f"/hardware/devices/{foreign_device_id}", headers=operator_headers)
    assert response.status_code == 403


def test_audit_logs_capture_transaction_and_report_activity(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    admin_headers = login(test_client, "admin", "admin123")
    manager_headers = login(test_client, "manager", "manager123")
    sale_response = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 1001,
            "rate_per_liter": 10,
            "sale_type": "cash",
        },
    )
    assert sale_response.status_code == 200, sale_response.text
    sale_id = sale_response.json()["id"]
    report_date = sale_response.json()["created_at"][:10]

    reverse_response = test_client.post(f"/fuel-sales/{sale_id}/reverse", headers=operator_headers)
    assert reverse_response.status_code == 200, reverse_response.text

    report_response = test_client.get(
        "/reports/daily-closing",
        params={"report_date": report_date},
        headers=manager_headers,
    )
    assert report_response.status_code == 200, report_response.text

    audit_response = test_client.get("/audit-logs/", params={"module": "fuel_sales"}, headers=admin_headers)
    assert audit_response.status_code == 200, audit_response.text
    actions = {entry["action"] for entry in audit_response.json()}
    assert "fuel_sales.create" in actions
    assert "fuel_sales.reverse" in actions

    report_audit_response = test_client.get("/audit-logs/", params={"module": "reports"}, headers=admin_headers)
    assert report_audit_response.status_code == 200
    report_actions = {entry["action"] for entry in report_audit_response.json()}
    assert "reports.daily_closing" in report_actions


def test_report_permissions_and_financial_reports(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    manager_headers = login(test_client, "manager", "manager123")
    accountant_headers = login(test_client, "accountant", "accountant123")
    forbidden_report = test_client.get(
        "/reports/daily-closing",
        params={"report_date": date.today().isoformat()},
        headers=operator_headers,
    )
    assert forbidden_report.status_code == 403

    sale_response = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 1005,
            "rate_per_liter": 10,
            "sale_type": "cash",
        },
    )
    assert sale_response.status_code == 200, sale_response.text
    report_date = sale_response.json()["created_at"][:10]

    expense_response = test_client.post(
        "/expenses/",
        headers=manager_headers,
        json={
            "title": "Office Supplies",
            "category": "Admin",
            "amount": 15,
            "station_id": data["station_a_id"],
        },
    )
    assert expense_response.status_code == 200, expense_response.text

    purchase_response = test_client.post(
        "/purchases/",
        headers=operator_headers,
        json={
            "supplier_id": 1,
            "tank_id": data["tank_id"],
            "fuel_type_id": data["fuel_type_id"],
            "quantity": 20,
            "rate_per_liter": 5,
        },
    )
    assert purchase_response.status_code == 200, purchase_response.text

    daily_report = test_client.get(
        "/reports/daily-closing",
        params={"report_date": report_date},
        headers=accountant_headers,
    )
    assert daily_report.status_code == 200, daily_report.text
    report_json = daily_report.json()
    assert report_json["fuel_cash_sales"] == 50
    assert report_json["expenses"] == 15
    assert report_json["cash_inflows"] == 50
    assert report_json["cash_outflows"] == 15
    assert report_json["net_cash_movement"] == 35

    stock_report = test_client.get("/reports/stock-movement", headers=manager_headers)
    assert stock_report.status_code == 200, stock_report.text
    first_tank = stock_report.json()["items"][0]
    assert first_tank["purchased_liters"] == 20
    assert first_tank["sold_liters"] == 5
    assert first_tank["current_volume_liters"] == 115


def test_operator_cannot_view_audit_logs_or_create_expenses(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")

    audit_response = test_client.get("/audit-logs/", headers=operator_headers)
    assert audit_response.status_code == 403

    expense_response = test_client.post(
        "/expenses/",
        headers=operator_headers,
        json={
            "title": "Unauthorized Expense",
            "category": "Ops",
            "amount": 10,
            "station_id": data["station_a_id"],
        },
    )
    assert expense_response.status_code == 403
