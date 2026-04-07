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


def test_vendor_api_hardware_adapter_poll_flow(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")

    vendors_response = test_client.get("/hardware/vendors", headers=manager_headers)
    assert vendors_response.status_code == 200, vendors_response.text
    assert "gilbarco" in vendors_response.json()["recognized_vendors"]

    invalid_vendor_response = test_client.post(
        "/hardware/devices",
        headers=manager_headers,
        json={
            "name": "Invalid Veeder Dispenser",
            "code": "HW-VENDOR-BAD",
            "device_type": "dispenser",
            "vendor_name": "veederroot",
            "integration_mode": "vendor_api",
            "protocol": "https",
            "endpoint_url": "https://vendor.example/api/device",
            "device_identifier": "VR-001",
            "status": "offline",
            "station_id": data["station_a_id"],
            "dispenser_id": 1,
        },
    )
    assert invalid_vendor_response.status_code == 400

    vendor_device_response = test_client.post(
        "/hardware/devices",
        headers=manager_headers,
        json={
            "name": "Gilbarco Controller",
            "code": "HW-VENDOR-001",
            "device_type": "dispenser",
            "vendor_name": "gilbarco",
            "integration_mode": "vendor_api",
            "protocol": "https",
            "endpoint_url": "https://vendor.example/api/device",
            "device_identifier": "GIL-001",
            "api_key": "secret-token",
            "status": "offline",
            "station_id": data["station_a_id"],
            "dispenser_id": 1,
        },
    )
    assert vendor_device_response.status_code == 200, vendor_device_response.text
    vendor_device_id = vendor_device_response.json()["id"]
    assert vendor_device_response.json()["protocol"] == "https"
    assert vendor_device_response.json()["device_identifier"] == "GIL-001"

    adapter_check_response = test_client.post(
        f"/hardware/devices/{vendor_device_id}/adapter-check",
        headers=manager_headers,
    )
    assert adapter_check_response.status_code == 200, adapter_check_response.text
    assert adapter_check_response.json()["vendor_name"] == "gilbarco"
    assert adapter_check_response.json()["status"] == "configured"

    vendor_poll_response = test_client.post(
        f"/hardware/devices/{vendor_device_id}/vendor-poll",
        headers=manager_headers,
    )
    assert vendor_poll_response.status_code == 200, vendor_poll_response.text
    assert vendor_poll_response.json()["event_type"] == "vendor_dispenser_poll"
    assert vendor_poll_response.json()["meter_reading"] == 1015.5

    db = session_local()
    try:
        device = db.query(HardwareDevice).filter(HardwareDevice.id == vendor_device_id).first()
        assert device.status == "online"
        assert device.last_seen_at is not None
    finally:
        db.close()


def test_tanker_module_workflows_and_station_toggle(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    admin_headers = login(test_client, "stationadmin", "station123")
    manager_headers = login(test_client, "manager", "manager123")
    foreign_manager_headers = login(test_client, "foreignmanager", "foreign123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    disabled_tanker = test_client.post(
        "/tankers/",
        headers=admin_headers,
        json={
            "registration_no": "TK-DISABLED",
            "name": "Disabled Tanker",
            "capacity": 5000,
            "station_id": data["station_b_id"],
            "fuel_type_id": data["fuel_type_id"],
        },
    )
    assert disabled_tanker.status_code == 403

    tanker_response = test_client.post(
        "/tankers/",
        headers=manager_headers,
        json={
            "registration_no": "TK-001",
            "name": "Owned Tanker",
            "capacity": 5000,
            "ownership_type": "owned",
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "compartments": [
                {"code": "C1", "name": "Front", "capacity": 2500, "position": 1},
                {"code": "C2", "name": "Rear", "capacity": 2500, "position": 2},
            ],
        },
    )
    assert tanker_response.status_code == 200, tanker_response.text
    tanker_id = tanker_response.json()["id"]
    assert len(tanker_response.json()["compartments"]) == 2

    supplier_station_trip = test_client.post(
        "/tankers/trips",
        headers=manager_headers,
        json={
            "tanker_id": tanker_id,
            "supplier_id": 1,
            "fuel_type_id": data["fuel_type_id"],
            "trip_type": "supplier_to_station",
            "linked_tank_id": data["tank_id"],
            "destination_name": "Station Storage",
            "loaded_quantity": 20,
            "purchase_rate": 5,
        },
    )
    assert supplier_station_trip.status_code == 200, supplier_station_trip.text
    trip_id = supplier_station_trip.json()["id"]

    add_delivery = test_client.post(
        f"/tankers/trips/{trip_id}/deliveries",
        headers=manager_headers,
        json={
            "destination_name": "Main Station Tank",
            "quantity": 20,
            "fuel_rate": 5,
            "delivery_charge": 0,
            "sale_type": "cash",
            "paid_amount": 100,
        },
    )
    assert add_delivery.status_code == 200, add_delivery.text

    add_expense = test_client.post(
        f"/tankers/trips/{trip_id}/expenses",
        headers=manager_headers,
        json={"expense_type": "toll", "amount": 10, "notes": "Bridge toll"},
    )
    assert add_expense.status_code == 200, add_expense.text

    complete_trip = test_client.post(
        f"/tankers/trips/{trip_id}/complete",
        headers=manager_headers,
        json={"reason": "Delivery completed"},
    )
    assert complete_trip.status_code == 200, complete_trip.text
    completed_trip = complete_trip.json()
    assert completed_trip["status"] == "completed"
    assert completed_trip["linked_purchase_id"] is not None
    assert completed_trip["net_profit"] == -10
    assert completed_trip["compartment_plan"][0]["quantity"] == 20

    station_summary = test_client.get(
        f"/tankers/summary?station_id={data['station_a_id']}",
        headers=manager_headers,
    )
    assert station_summary.status_code == 200, station_summary.text
    station_summary_json = station_summary.json()
    assert station_summary_json["tanker_count"] == 1
    assert station_summary_json["ownership_breakdown"]["owned"] == 1
    assert station_summary_json["supplier_to_station_trip_count"] == 1

    db = session_local()
    try:
        from app.models.customer import Customer
        from app.models.supplier import Supplier
        from app.models.tank import Tank

        tank = db.query(Tank).filter(Tank.id == data["tank_id"]).first()
        supplier = db.query(Supplier).filter(Supplier.id == 1).first()
        assert tank.current_volume == 120
        assert supplier.payable_balance == 100

        foreign_customer = Customer(
            name="Pump Buyer",
            code="PUMP-BUYER",
            customer_type="company",
            phone="777",
            address="Buyer Station",
            credit_limit=1000,
            outstanding_balance=0,
            station_id=data["station_c_id"],
        )
        db.add(foreign_customer)
        db.commit()
        foreign_customer_id = foreign_customer.id
    finally:
        db.close()

    foreign_tanker = test_client.post(
        "/tankers/",
        headers=foreign_manager_headers,
        json={
            "registration_no": "TK-002",
            "name": "Foreign Tanker",
            "capacity": 7000,
            "ownership_type": "third_party",
            "station_id": data["station_c_id"],
            "fuel_type_id": data["fuel_type_id"],
        },
    )
    assert foreign_tanker.status_code == 200, foreign_tanker.text
    foreign_tanker_id = foreign_tanker.json()["id"]

    direct_sale_trip = test_client.post(
        "/tankers/trips",
        headers=foreign_manager_headers,
        json={
            "tanker_id": foreign_tanker_id,
            "supplier_id": 1,
            "fuel_type_id": data["fuel_type_id"],
            "trip_type": "supplier_to_customer",
            "destination_name": "Other Pump",
            "loaded_quantity": 20,
            "purchase_rate": 6,
        },
    )
    assert direct_sale_trip.status_code == 200, direct_sale_trip.text
    direct_trip_id = direct_sale_trip.json()["id"]

    direct_delivery = test_client.post(
        f"/tankers/trips/{direct_trip_id}/deliveries",
        headers=foreign_manager_headers,
        json={
            "customer_id": foreign_customer_id,
            "destination_name": "Other Pump",
            "quantity": 15,
            "fuel_rate": 8,
            "delivery_charge": 20,
            "sale_type": "credit",
            "paid_amount": 0,
        },
    )
    assert direct_delivery.status_code == 200, direct_delivery.text

    direct_expense = test_client.post(
        f"/tankers/trips/{direct_trip_id}/expenses",
        headers=foreign_manager_headers,
        json={"expense_type": "driver", "amount": 12, "notes": "Driver allowance"},
    )
    assert direct_expense.status_code == 200, direct_expense.text

    complete_direct_trip = test_client.post(
        f"/tankers/trips/{direct_trip_id}/complete",
        headers=foreign_manager_headers,
        json={
            "reason": "Customer delivery completed",
            "transfer_to_tank_id": data["foreign_tank_id"],
        },
    )
    assert complete_direct_trip.status_code == 200, complete_direct_trip.text
    assert complete_direct_trip.json()["status"] == "completed"
    assert complete_direct_trip.json()["net_profit"] == 38
    assert complete_direct_trip.json()["leftover_quantity"] == 5
    assert complete_direct_trip.json()["transferred_quantity"] == 5
    assert complete_direct_trip.json()["fuel_transfers"][0]["tank_id"] == data["foreign_tank_id"]

    foreign_summary = test_client.get(
        f"/tankers/summary?station_id={data['station_c_id']}",
        headers=foreign_manager_headers,
    )
    assert foreign_summary.status_code == 200, foreign_summary.text
    foreign_summary_json = foreign_summary.json()
    assert foreign_summary_json["supplier_to_customer_trip_count"] == 1
    assert foreign_summary_json["total_leftover_quantity"] == 5
    assert foreign_summary_json["total_transferred_quantity"] == 5

    db = session_local()
    try:
        from app.models.customer import Customer

        from app.models.tank import Tank

        foreign_customer = db.query(Customer).filter(Customer.id == foreign_customer_id).first()
        foreign_tank = db.query(Tank).filter(Tank.id == data["foreign_tank_id"]).first()
        assert foreign_customer.outstanding_balance == 140
        assert foreign_tank.current_volume == 105
    finally:
        db.close()

    head_office_trip_list = test_client.get("/tankers/trips", headers=head_office_headers)
    assert head_office_trip_list.status_code == 200, head_office_trip_list.text
    trip_ids = {trip["id"] for trip in head_office_trip_list.json()}
    assert trip_id in trip_ids
    assert direct_trip_id not in trip_ids
