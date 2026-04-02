from app.models.customer import Customer
from app.models.dispenser import Dispenser
from app.models.expense import Expense
from app.models.hardware_device import HardwareDevice

from tests.conftest import login, seed_base_data


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


def test_operator_cannot_create_customer_or_tanker_master_data(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")

    customer_response = test_client.post(
        "/customers/",
        headers=operator_headers,
        json={
            "name": "Customer Z",
            "code": "CUST-Z",
            "customer_type": "company",
            "phone": "999",
            "address": "Addr Z",
            "credit_limit": 100,
            "station_id": data["station_a_id"],
        },
    )
    assert customer_response.status_code == 403

    tanker_response = test_client.post(
        "/tankers/",
        headers=operator_headers,
        json={
            "registration_no": "TK-001",
            "name": "Tanker One",
            "capacity": 5000,
            "owner_name": "Owner",
            "driver_name": "Driver",
            "driver_phone": "12345",
            "status": "available",
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
        },
    )
    assert tanker_response.status_code == 403
