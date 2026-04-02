from app.models.customer import Customer
from app.models.nozzle import Nozzle
from app.models.supplier import Supplier
from app.models.tank import Tank

from tests.conftest import login, seed_base_data


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
