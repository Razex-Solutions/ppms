from app.models.customer import Customer
from app.models.meter_adjustment_event import MeterAdjustmentEvent
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
    operator_headers = login(test_client, "operator", "operator123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    create_response = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
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

    get_response = test_client.get(f"/fuel-sales/{sale['id']}", headers=operator_headers)
    assert get_response.status_code == 200
    assert get_response.json()["id"] == sale["id"]

    reverse_response = test_client.post(
        f"/fuel-sales/{sale['id']}/reverse",
        headers=operator_headers,
        json={"reason": "Meter correction requested"},
    )
    assert reverse_response.status_code == 200, reverse_response.text
    assert reverse_response.json()["is_reversed"] is False
    assert reverse_response.json()["reversal_request_status"] == "pending"

    approval_response = test_client.post(
        f"/fuel-sales/{sale['id']}/approve-reversal",
        headers=head_office_headers,
        json={"reason": "Approved by head office"},
    )
    assert approval_response.status_code == 200, approval_response.text
    assert approval_response.json()["is_reversed"] is True
    assert approval_response.json()["reversal_request_status"] == "approved"

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
    operator_headers = login(test_client, "operator", "operator123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

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
        headers=operator_headers,
        json={
            "customer_id": data["customer_id"],
            "station_id": data["station_a_id"],
            "amount": 30,
            "payment_method": "cash",
        },
    )
    assert customer_payment.status_code == 200, customer_payment.text
    customer_payment_id = customer_payment.json()["id"]

    customer_payment_detail = test_client.get(f"/customer-payments/{customer_payment_id}", headers=operator_headers)
    assert customer_payment_detail.status_code == 200

    customer_payment_reverse = test_client.post(
        f"/customer-payments/{customer_payment_id}/reverse",
        headers=operator_headers,
        json={"reason": "Applied to wrong customer"},
    )
    assert customer_payment_reverse.status_code == 200
    assert customer_payment_reverse.json()["is_reversed"] is False
    assert customer_payment_reverse.json()["reversal_request_status"] == "pending"

    customer_payment_approve = test_client.post(
        f"/customer-payments/{customer_payment_id}/approve-reversal",
        headers=head_office_headers,
        json={"reason": "Approved"},
    )
    assert customer_payment_approve.status_code == 200
    assert customer_payment_approve.json()["is_reversed"] is True

    supplier_payment = test_client.post(
        "/supplier-payments/",
        headers=operator_headers,
        json={
            "supplier_id": supplier_id,
            "station_id": data["station_a_id"],
            "amount": 40,
            "payment_method": "cash",
        },
    )
    assert supplier_payment.status_code == 200, supplier_payment.text
    supplier_payment_id = supplier_payment.json()["id"]

    supplier_payment_detail = test_client.get(f"/supplier-payments/{supplier_payment_id}", headers=operator_headers)
    assert supplier_payment_detail.status_code == 200

    supplier_payment_reverse = test_client.post(
        f"/supplier-payments/{supplier_payment_id}/reverse",
        headers=operator_headers,
        json={"reason": "Wrong supplier payment"},
    )
    assert supplier_payment_reverse.status_code == 200
    assert supplier_payment_reverse.json()["is_reversed"] is False
    assert supplier_payment_reverse.json()["reversal_request_status"] == "pending"

    supplier_payment_approve = test_client.post(
        f"/supplier-payments/{supplier_payment_id}/approve-reversal",
        headers=head_office_headers,
        json={"reason": "Approved"},
    )
    assert supplier_payment_approve.status_code == 200
    assert supplier_payment_approve.json()["is_reversed"] is True


def test_purchase_reverse_updates_payables_dashboard(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    db = session_local()
    try:
        supplier = db.query(Supplier).filter(Supplier.code == "SUP-A").first()
        supplier_id = supplier.id
    finally:
        db.close()

    purchase_response = test_client.post(
        "/purchases/",
        headers=operator_headers,
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
    assert purchase_response.json()["status"] == "pending"

    dashboard_before = test_client.get("/dashboard/", headers=operator_headers)
    assert dashboard_before.status_code == 200
    assert dashboard_before.json()["payables"] == 0

    approve_purchase_response = test_client.post(
        f"/purchases/{purchase_id}/approve",
        headers=head_office_headers,
        json={"reason": "Approved delivery"},
    )
    assert approve_purchase_response.status_code == 200, approve_purchase_response.text
    assert approve_purchase_response.json()["status"] == "approved"

    dashboard_after_approval = test_client.get("/dashboard/", headers=operator_headers)
    assert dashboard_after_approval.status_code == 200
    assert dashboard_after_approval.json()["payables"] == 100

    reverse_response = test_client.post(
        f"/purchases/{purchase_id}/reverse",
        headers=operator_headers,
        json={"reason": "Duplicate purchase"},
    )
    assert reverse_response.status_code == 200
    assert reverse_response.json()["is_reversed"] is False
    assert reverse_response.json()["reversal_request_status"] == "pending"

    approve_response = test_client.post(
        f"/purchases/{purchase_id}/approve-reversal",
        headers=head_office_headers,
        json={"reason": "Approved duplicate rollback"},
    )
    assert approve_response.status_code == 200
    assert approve_response.json()["is_reversed"] is True

    dashboard_after = test_client.get("/dashboard/", headers=operator_headers)
    assert dashboard_after.status_code == 200
    assert dashboard_after.json()["payables"] == 0


def test_purchase_requires_approval_before_affecting_stock_and_can_be_rejected(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    purchase_response = test_client.post(
        "/purchases/",
        headers=operator_headers,
        json={
            "supplier_id": 1,
            "tank_id": data["tank_id"],
            "fuel_type_id": data["fuel_type_id"],
            "quantity": 10,
            "rate_per_liter": 5,
        },
    )
    assert purchase_response.status_code == 200, purchase_response.text
    purchase_id = purchase_response.json()["id"]
    assert purchase_response.json()["status"] == "pending"

    db = session_local()
    try:
        tank = db.query(Tank).filter(Tank.id == data["tank_id"]).first()
        supplier = db.query(Supplier).filter(Supplier.id == 1).first()
        assert tank.current_volume == 100
        assert supplier.payable_balance == 0
    finally:
        db.close()

    reject_response = test_client.post(
        f"/purchases/{purchase_id}/reject",
        headers=head_office_headers,
        json={"reason": "Missing paperwork"},
    )
    assert reject_response.status_code == 200, reject_response.text
    assert reject_response.json()["status"] == "rejected"


def test_shift_close_ignores_reversed_sales(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    shift_response = test_client.post(
        "/shifts/",
        headers=operator_headers,
        json={"station_id": data["station_a_id"], "initial_cash": 50},
    )
    assert shift_response.status_code == 200, shift_response.text
    shift_id = shift_response.json()["id"]

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
            "shift_id": shift_id,
        },
    )
    assert sale_response.status_code == 200, sale_response.text
    sale_id = sale_response.json()["id"]

    reverse_response = test_client.post(
        f"/fuel-sales/{sale_id}/reverse",
        headers=operator_headers,
        json={"reason": "Incorrect sale"},
    )
    assert reverse_response.status_code == 200
    approve_response = test_client.post(
        f"/fuel-sales/{sale_id}/approve-reversal",
        headers=head_office_headers,
        json={"reason": "Approved correction"},
    )
    assert approve_response.status_code == 200

    close_response = test_client.post(
        f"/shifts/{shift_id}/close",
        headers=operator_headers,
        json={"actual_cash_collected": 50},
    )
    assert close_response.status_code == 200, close_response.text
    closed_shift = close_response.json()
    assert closed_shift["total_sales_cash"] == 0
    assert closed_shift["expected_cash"] == 50
    assert closed_shift["difference"] == 0


def test_credit_override_approval_allows_credit_sale_over_limit(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    db = session_local()
    try:
        customer = db.query(Customer).filter(Customer.id == data["customer_id"]).first()
        customer.outstanding_balance = 490
        db.commit()
    finally:
        db.close()

    blocked_sale = test_client.post(
        "/fuel-sales/",
        headers=manager_headers,
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
    assert blocked_sale.status_code == 400
    assert blocked_sale.json()["detail"] == "Credit limit exceeded"

    override_request = test_client.post(
        f"/customers/{data['customer_id']}/request-credit-override",
        headers=manager_headers,
        json={"amount": 20, "reason": "Emergency fleet fueling"},
    )
    assert override_request.status_code == 200, override_request.text
    assert override_request.json()["credit_override_status"] == "pending"

    override_approval = test_client.post(
        f"/customers/{data['customer_id']}/approve-credit-override",
        headers=head_office_headers,
        json={"amount": 20, "reason": "Approved"},
    )
    assert override_approval.status_code == 200, override_approval.text
    assert override_approval.json()["credit_override_status"] == "approved"
    assert override_approval.json()["credit_override_amount"] == 20

    allowed_sale = test_client.post(
        "/fuel-sales/",
        headers=manager_headers,
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
    assert allowed_sale.status_code == 200, allowed_sale.text

    db = session_local()
    try:
        customer = db.query(Customer).filter(Customer.id == data["customer_id"]).first()
        assert customer.outstanding_balance == 510
        assert customer.credit_override_amount == 10
        assert customer.credit_override_status == "approved"
    finally:
        db.close()


def test_meter_adjustment_starts_new_sales_segment_without_breaking_tank_deduction(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    admin_headers = login(test_client, "admin", "admin123")
    accountant_headers = login(test_client, "accountant", "accountant123")

    db = session_local()
    try:
        tank = db.query(Tank).filter(Tank.id == data["tank_id"]).first()
        tank.current_volume = 1000
        db.commit()
    finally:
        db.close()

    first_sale = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 1080,
            "rate_per_liter": 10,
            "sale_type": "cash",
        },
    )
    assert first_sale.status_code == 200, first_sale.text
    assert first_sale.json()["quantity"] == 80

    adjustment = test_client.post(
        f"/nozzles/{data['nozzle_id']}/adjust-meter",
        headers=admin_headers,
        json={"new_reading": 600, "reason": "Meter reset after maintenance"},
    )
    assert adjustment.status_code == 200, adjustment.text
    assert adjustment.json()["old_reading"] == 1080
    assert adjustment.json()["new_reading"] == 600

    second_sale = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 670,
            "rate_per_liter": 10,
            "sale_type": "cash",
        },
    )
    assert second_sale.status_code == 200, second_sale.text
    assert second_sale.json()["opening_meter"] == 600
    assert second_sale.json()["quantity"] == 70

    adjustments = test_client.get(f"/nozzles/{data['nozzle_id']}/adjustments", headers=accountant_headers)
    assert adjustments.status_code == 200, adjustments.text
    assert len(adjustments.json()) == 1
    assert adjustments.json()[0]["reason"] == "Meter reset after maintenance"

    db = session_local()
    try:
        nozzle = db.query(Nozzle).filter(Nozzle.id == data["nozzle_id"]).first()
        tank = db.query(Tank).filter(Tank.id == data["tank_id"]).first()
        adjustment_event = db.query(MeterAdjustmentEvent).filter(MeterAdjustmentEvent.nozzle_id == data["nozzle_id"]).first()
        assert nozzle.meter_reading == 670
        assert nozzle.current_segment_start_reading == 600
        assert tank.current_volume == 1000 - 80 - 70
        assert adjustment_event is not None
    finally:
        db.close()
