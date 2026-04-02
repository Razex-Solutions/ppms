from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import create_app
from app.models.hardware_device import HardwareDevice

from tests.conftest import login, seed_base_data


def test_pos_product_and_sale_flow_with_reverse_and_module_toggle(client, tmp_path):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")
    operator_headers = login(test_client, "operator", "operator123")

    forbidden_product_response = test_client.post(
        "/pos-products/",
        headers=operator_headers,
        json={
            "name": "Forbidden Product",
            "code": "POS-FORBID",
            "category": "Lubricants",
            "module": "mart",
            "price": 25,
            "stock_quantity": 10,
            "track_inventory": True,
            "station_id": data["station_a_id"],
        },
    )
    assert forbidden_product_response.status_code == 403

    product_response = test_client.post(
        "/pos-products/",
        headers=manager_headers,
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

    delete_response = test_client.delete(f"/pos-products/{product_id}", headers=manager_headers)
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
