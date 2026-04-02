from datetime import date

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import create_app

from tests.conftest import login, seed_base_data


def test_audit_logs_capture_transaction_and_report_activity(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")
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

    reverse_response = test_client.post(
        f"/fuel-sales/{sale_id}/reverse",
        headers=operator_headers,
        json={"reason": "Requested for audit flow"},
    )
    assert reverse_response.status_code == 200, reverse_response.text
    approve_response = test_client.post(
        f"/fuel-sales/{sale_id}/approve-reversal",
        headers=head_office_headers,
        json={"reason": "Approved for audit flow"},
    )
    assert approve_response.status_code == 200, approve_response.text

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
    assert "fuel_sales.request_reversal" in actions
    assert "fuel_sales.approve_reversal" in actions
    assert "fuel_sales.reverse" in actions

    report_audit_response = test_client.get("/audit-logs/", params={"module": "reports"}, headers=admin_headers)
    assert report_audit_response.status_code == 200
    report_actions = {entry["action"] for entry in report_audit_response.json()}
    assert "reports.daily_closing" in report_actions


def test_head_office_audit_logs_are_organization_scoped(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    foreign_manager_headers = login(test_client, "foreignmanager", "foreign123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    local_sale = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 1006,
            "rate_per_liter": 10,
            "sale_type": "cash",
        },
    )
    assert local_sale.status_code == 200, local_sale.text

    db = session_local()
    try:
        from app.models.dispenser import Dispenser
        from app.models.fuel_type import FuelType
        from app.models.nozzle import Nozzle
        from app.models.station import Station
        from app.models.tank import Tank

        station_c = db.query(Station).filter(Station.id == data["station_c_id"]).first()
        fuel_type = db.query(FuelType).filter(FuelType.id == data["fuel_type_id"]).first()
        foreign_tank = Tank(
            name="Tank CX",
            code="TANK-CX",
            capacity=1000,
            current_volume=200,
            low_stock_threshold=30,
            location="Rear",
            station_id=station_c.id,
            fuel_type_id=fuel_type.id,
        )
        db.add(foreign_tank)
        db.flush()
        foreign_dispenser = Dispenser(
            name="Dispenser CX",
            code="DISP-CX",
            location="Rear",
            station_id=station_c.id,
        )
        db.add(foreign_dispenser)
        db.flush()
        foreign_nozzle = Nozzle(
            name="Nozzle CX",
            code="NOZ-CX",
            meter_reading=500,
            dispenser_id=foreign_dispenser.id,
            tank_id=foreign_tank.id,
            fuel_type_id=fuel_type.id,
        )
        db.add(foreign_nozzle)
        db.commit()
        foreign_nozzle_id = foreign_nozzle.id
    finally:
        db.close()

    foreign_sale = test_client.post(
        "/fuel-sales/",
        headers=foreign_manager_headers,
        json={
            "nozzle_id": foreign_nozzle_id,
            "station_id": data["station_c_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 505,
            "rate_per_liter": 10,
            "sale_type": "cash",
        },
    )
    assert foreign_sale.status_code == 200, foreign_sale.text

    head_office_audits = test_client.get("/audit-logs/", params={"module": "fuel_sales"}, headers=head_office_headers)
    assert head_office_audits.status_code == 200, head_office_audits.text
    returned_station_ids = {entry["station_id"] for entry in head_office_audits.json()}
    assert data["station_a_id"] in returned_station_ids
    assert data["station_c_id"] not in returned_station_ids

    forbidden_foreign_station = test_client.get(
        "/audit-logs/",
        params={"station_id": data["station_c_id"]},
        headers=head_office_headers,
    )
    assert forbidden_foreign_station.status_code == 403


def test_report_permissions_and_financial_reports(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    manager_headers = login(test_client, "manager", "manager123")
    accountant_headers = login(test_client, "accountant", "accountant123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")
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
    assert expense_response.json()["status"] == "pending"

    expense_approval = test_client.post(
        f"/expenses/{expense_response.json()['id']}/approve",
        headers=head_office_headers,
        json={"reason": "Approved for reporting"},
    )
    assert expense_approval.status_code == 200, expense_approval.text
    assert expense_approval.json()["status"] == "approved"

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
    purchase_approval = test_client.post(
        f"/purchases/{purchase_response.json()['id']}/approve",
        headers=head_office_headers,
        json={"reason": "Approved delivery"},
    )
    assert purchase_approval.status_code == 200, purchase_approval.text

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


def test_head_office_reports_and_dashboard_are_organization_scoped(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    manager_headers = login(test_client, "manager", "manager123")
    foreign_manager_headers = login(test_client, "foreignmanager", "foreign123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    local_sale = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 1004,
            "rate_per_liter": 10,
            "sale_type": "cash",
        },
    )
    assert local_sale.status_code == 200, local_sale.text
    report_date = local_sale.json()["created_at"][:10]

    local_expense = test_client.post(
        "/expenses/",
        headers=manager_headers,
        json={
            "title": "Station A Expense",
            "category": "Admin",
            "amount": 12,
            "station_id": data["station_a_id"],
        },
    )
    assert local_expense.status_code == 200, local_expense.text
    local_expense_approval = test_client.post(
        f"/expenses/{local_expense.json()['id']}/approve",
        headers=head_office_headers,
        json={"reason": "Approved for org dashboard"},
    )
    assert local_expense_approval.status_code == 200, local_expense_approval.text

    db = session_local()
    try:
        from app.models.customer import Customer
        from app.models.dispenser import Dispenser
        from app.models.fuel_type import FuelType
        from app.models.nozzle import Nozzle
        from app.models.station import Station
        from app.models.tank import Tank

        station_c = db.query(Station).filter(Station.id == data["station_c_id"]).first()
        fuel_type = db.query(FuelType).filter(FuelType.id == data["fuel_type_id"]).first()
        foreign_tank = Tank(
            name="Tank C",
            code="TANK-C",
            capacity=1000,
            current_volume=200,
            low_stock_threshold=30,
            location="Rear",
            station_id=station_c.id,
            fuel_type_id=fuel_type.id,
        )
        db.add(foreign_tank)
        db.flush()
        foreign_dispenser = Dispenser(
            name="Dispenser C",
            code="DISP-C",
            location="Rear",
            station_id=station_c.id,
        )
        db.add(foreign_dispenser)
        db.flush()
        foreign_nozzle = Nozzle(
            name="Nozzle C",
            code="NOZ-C",
            meter_reading=500,
            dispenser_id=foreign_dispenser.id,
            tank_id=foreign_tank.id,
            fuel_type_id=fuel_type.id,
        )
        foreign_customer = Customer(
            name="Customer C",
            code="CUST-C",
            customer_type="company",
            phone="999",
            address="Addr C",
            credit_limit=1000,
            outstanding_balance=0,
            station_id=station_c.id,
        )
        db.add_all([foreign_nozzle, foreign_customer])
        db.commit()
        foreign_nozzle_id = foreign_nozzle.id
    finally:
        db.close()

    foreign_sale = test_client.post(
        "/fuel-sales/",
        headers=foreign_manager_headers,
        json={
            "nozzle_id": foreign_nozzle_id,
            "station_id": data["station_c_id"],
            "fuel_type_id": data["fuel_type_id"],
            "closing_meter": 505,
            "rate_per_liter": 10,
            "sale_type": "cash",
        },
    )
    assert foreign_sale.status_code == 200, foreign_sale.text

    head_office_report = test_client.get(
        "/reports/daily-closing",
        params={"report_date": report_date},
        headers=head_office_headers,
    )
    assert head_office_report.status_code == 200, head_office_report.text
    assert head_office_report.json()["organization_id"] == data["organization_id"]
    assert head_office_report.json()["fuel_cash_sales"] == 40
    assert head_office_report.json()["expenses"] == 12

    foreign_org_report = test_client.get(
        "/reports/daily-closing",
        params={"report_date": report_date, "organization_id": data["foreign_organization_id"]},
        headers=head_office_headers,
    )
    assert foreign_org_report.status_code == 200
    assert foreign_org_report.json()["organization_id"] == data["organization_id"]
    assert foreign_org_report.json()["fuel_cash_sales"] == 40

    forbidden_station_report = test_client.get(
        "/reports/daily-closing",
        params={"report_date": report_date, "station_id": data["station_c_id"]},
        headers=head_office_headers,
    )
    assert forbidden_station_report.status_code == 403

    dashboard_response = test_client.get("/dashboard/", headers=head_office_headers)
    assert dashboard_response.status_code == 200, dashboard_response.text
    assert dashboard_response.json()["filters"]["organization_id"] == data["organization_id"]
    assert dashboard_response.json()["sales"]["total"] == 40


def test_expense_approval_workflow_controls_financial_reporting(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")
    accountant_headers = login(test_client, "accountant", "accountant123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    pending_expense = test_client.post(
        "/expenses/",
        headers=manager_headers,
        json={
            "title": "Pending Expense",
            "category": "Ops",
            "amount": 25,
            "station_id": data["station_a_id"],
        },
    )
    assert pending_expense.status_code == 200, pending_expense.text
    expense_id = pending_expense.json()["id"]
    assert pending_expense.json()["status"] == "pending"

    pending_report = test_client.get(
        "/reports/daily-closing",
        params={"report_date": pending_expense.json()["created_at"][:10]},
        headers=accountant_headers,
    )
    assert pending_report.status_code == 200
    assert pending_report.json()["expenses"] == 0

    manager_approve_attempt = test_client.post(
        f"/expenses/{expense_id}/approve",
        headers=manager_headers,
        json={"reason": "Self approval"},
    )
    assert manager_approve_attempt.status_code == 403

    approval_response = test_client.post(
        f"/expenses/{expense_id}/approve",
        headers=head_office_headers,
        json={"reason": "Approved by head office"},
    )
    assert approval_response.status_code == 200, approval_response.text
    assert approval_response.json()["status"] == "approved"

    approved_report = test_client.get(
        "/reports/daily-closing",
        params={"report_date": pending_expense.json()["created_at"][:10]},
        headers=accountant_headers,
    )
    assert approved_report.status_code == 200
    assert approved_report.json()["expenses"] == 25

    reject_after_approval = test_client.post(
        f"/expenses/{expense_id}/reject",
        headers=head_office_headers,
        json={"reason": "Too late"},
    )
    assert reject_after_approval.status_code == 400


def test_report_exports_create_and_download_csv(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    manager_headers = login(test_client, "manager", "manager123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

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
            "title": "CSV Expense",
            "category": "Ops",
            "amount": 15,
            "station_id": data["station_a_id"],
        },
    )
    assert expense_response.status_code == 200, expense_response.text

    expense_approval = test_client.post(
        f"/expenses/{expense_response.json()['id']}/approve",
        headers=head_office_headers,
        json={"reason": "Approved for export"},
    )
    assert expense_approval.status_code == 200, expense_approval.text

    export_response = test_client.post(
        "/report-exports/",
        headers=head_office_headers,
        json={"report_type": "daily_closing", "report_date": report_date, "format": "csv"},
    )
    assert export_response.status_code == 200, export_response.text
    export_job = export_response.json()
    assert export_job["report_type"] == "daily_closing"
    assert export_job["status"] == "completed"

    list_response = test_client.get("/report-exports/", headers=head_office_headers)
    assert list_response.status_code == 200, list_response.text
    assert any(job["id"] == export_job["id"] for job in list_response.json())

    download_response = test_client.get(f"/report-exports/{export_job['id']}/download", headers=head_office_headers)
    assert download_response.status_code == 200, download_response.text
    assert download_response.headers["content-type"].startswith("text/csv")
    assert "field,value" in download_response.text
    assert "fuel_cash_sales,50" in download_response.text


def test_head_office_cannot_access_foreign_organization_report_exports(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    foreign_manager_headers = login(test_client, "foreignmanager", "foreign123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    db = session_local()
    try:
        from app.models.customer import Customer

        foreign_customer = Customer(
            name="Foreign Export Customer",
            code="CUST-FX",
            customer_type="company",
            phone="888",
            address="Foreign Addr",
            credit_limit=500,
            outstanding_balance=75,
            station_id=data["station_c_id"],
        )
        db.add(foreign_customer)
        db.commit()
    finally:
        db.close()

    foreign_export = test_client.post(
        "/report-exports/",
        headers=foreign_manager_headers,
        json={"report_type": "customer_balances", "format": "csv"},
    )
    assert foreign_export.status_code == 200, foreign_export.text
    foreign_job_id = foreign_export.json()["id"]

    forbidden_get = test_client.get(f"/report-exports/{foreign_job_id}", headers=head_office_headers)
    assert forbidden_get.status_code == 403

    forbidden_download = test_client.get(f"/report-exports/{foreign_job_id}/download", headers=head_office_headers)
    assert forbidden_download.status_code == 403


def test_tanker_reports_dashboard_and_exports(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")
    accountant_headers = login(test_client, "accountant", "accountant123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    tanker_response = test_client.post(
        "/tankers/",
        headers=manager_headers,
        json={
            "registration_no": "TK-RPT-001",
            "name": "Report Tanker",
            "capacity": 6000,
            "ownership_type": "owned",
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
        },
    )
    assert tanker_response.status_code == 200, tanker_response.text
    tanker_id = tanker_response.json()["id"]

    trip_response = test_client.post(
        "/tankers/trips",
        headers=manager_headers,
        json={
            "tanker_id": tanker_id,
            "supplier_id": 1,
            "fuel_type_id": data["fuel_type_id"],
            "trip_type": "supplier_to_customer",
            "destination_name": "Wholesale Pump",
        },
    )
    assert trip_response.status_code == 200, trip_response.text
    trip_id = trip_response.json()["id"]

    delivery_response = test_client.post(
        f"/tankers/trips/{trip_id}/deliveries",
        headers=manager_headers,
        json={
            "customer_id": data["customer_id"],
            "destination_name": "Wholesale Pump",
            "quantity": 12,
            "fuel_rate": 9,
            "delivery_charge": 18,
            "sale_type": "credit",
            "paid_amount": 20,
        },
    )
    assert delivery_response.status_code == 200, delivery_response.text

    expense_response = test_client.post(
        f"/tankers/trips/{trip_id}/expenses",
        headers=manager_headers,
        json={"expense_type": "driver", "amount": 11, "notes": "Driver allowance"},
    )
    assert expense_response.status_code == 200, expense_response.text

    complete_response = test_client.post(
        f"/tankers/trips/{trip_id}/complete",
        headers=manager_headers,
        json={"reason": "Completed for reporting"},
    )
    assert complete_response.status_code == 200, complete_response.text
    assert complete_response.json()["net_profit"] == 115

    profit_report = test_client.get("/reports/tanker-profit", headers=accountant_headers)
    assert profit_report.status_code == 200, profit_report.text
    profit_json = profit_report.json()
    assert profit_json["count"] == 1
    assert profit_json["total_fuel_revenue"] == 108
    assert profit_json["total_delivery_revenue"] == 18
    assert profit_json["total_expenses"] == 11
    assert profit_json["total_net_profit"] == 115

    delivery_report = test_client.get("/reports/tanker-deliveries", headers=head_office_headers)
    assert delivery_report.status_code == 200, delivery_report.text
    delivery_json = delivery_report.json()
    assert delivery_json["fuel_revenue"] == 108
    assert delivery_json["delivery_revenue"] == 18
    assert delivery_json["cash_collected"] == 20
    assert delivery_json["credit_outstanding"] == 106

    expense_report = test_client.get("/reports/tanker-expenses", headers=head_office_headers)
    assert expense_report.status_code == 200, expense_report.text
    assert expense_report.json()["total_expenses"] == 11

    dashboard_response = test_client.get("/dashboard/", headers=head_office_headers)
    assert dashboard_response.status_code == 200, dashboard_response.text
    tanker_summary = dashboard_response.json()["tanker"]
    assert tanker_summary["completed_trips"] == 1
    assert tanker_summary["fuel_revenue"] == 108
    assert tanker_summary["delivery_revenue"] == 18
    assert tanker_summary["total_expenses"] == 11
    assert tanker_summary["net_profit"] == 115
    assert tanker_summary["credit_outstanding"] == 106
    assert tanker_summary["expense_breakdown"]["driver"] == 11

    export_response = test_client.post(
        "/report-exports/",
        headers=head_office_headers,
        json={"report_type": "tanker_profit", "format": "csv"},
    )
    assert export_response.status_code == 200, export_response.text
    export_job_id = export_response.json()["id"]

    download_response = test_client.get(f"/report-exports/{export_job_id}/download", headers=head_office_headers)
    assert download_response.status_code == 200, download_response.text
    assert "trip_id" in download_response.text
    assert "115.0" in download_response.text


def test_validation_errors_include_request_id(client):
    test_client, _ = client

    response = test_client.post("/auth/login", json={"username": "admin"})

    assert response.status_code == 422
    assert response.headers["X-Request-ID"]
    assert response.json()["request_id"] == response.headers["X-Request-ID"]


def test_notifications_cover_approval_export_and_meter_events(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")
    accountant_headers = login(test_client, "accountant", "accountant123")
    admin_headers = login(test_client, "admin", "admin123")

    expense_response = test_client.post(
        "/expenses/",
        headers=manager_headers,
        json={
            "title": "Notify Expense",
            "category": "Ops",
            "amount": 22,
            "station_id": data["station_a_id"],
        },
    )
    assert expense_response.status_code == 200, expense_response.text
    expense_id = expense_response.json()["id"]

    head_office_notifications = test_client.get("/notifications/", headers=head_office_headers)
    assert head_office_notifications.status_code == 200, head_office_notifications.text
    assert any(
        n["event_type"] == "expense.pending_approval" and n["entity_id"] == expense_id
        for n in head_office_notifications.json()
    )

    approval_response = test_client.post(
        f"/expenses/{expense_id}/approve",
        headers=head_office_headers,
        json={"reason": "Approved for notifications"},
    )
    assert approval_response.status_code == 200, approval_response.text

    manager_notifications = test_client.get("/notifications/", headers=manager_headers)
    assert manager_notifications.status_code == 200, manager_notifications.text
    approved_notification = next(
        n for n in manager_notifications.json()
        if n["event_type"] == "expense.approved" and n["entity_id"] == expense_id
    )
    assert approved_notification["is_read"] is False

    mark_read = test_client.post(f"/notifications/{approved_notification['id']}/read", headers=manager_headers)
    assert mark_read.status_code == 200, mark_read.text
    assert mark_read.json()["is_read"] is True

    export_response = test_client.post(
        "/report-exports/",
        headers=head_office_headers,
        json={"report_type": "customer_balances", "format": "csv"},
    )
    assert export_response.status_code == 200, export_response.text
    export_id = export_response.json()["id"]

    export_notifications = test_client.get(
        "/notifications/",
        params={"event_type": "report_export.completed"},
        headers=head_office_headers,
    )
    assert export_notifications.status_code == 200
    assert any(n["entity_id"] == export_id for n in export_notifications.json())

    adjust_response = test_client.post(
        f"/nozzles/{data['nozzle_id']}/adjust-meter",
        headers=admin_headers,
        json={"new_reading": 900, "reason": "Pump calibration"},
    )
    assert adjust_response.status_code == 200, adjust_response.text

    accountant_notifications = test_client.get(
        "/notifications/",
        params={"event_type": "nozzle.meter_adjusted", "unread_only": True},
        headers=accountant_headers,
    )
    assert accountant_notifications.status_code == 200, accountant_notifications.text
    assert any(n["entity_type"] == "meter_adjustment_event" for n in accountant_notifications.json())

    read_all = test_client.post("/notifications/read-all", headers=accountant_headers)
    assert read_all.status_code == 200
    assert read_all.json()["marked_read"] >= 1


def test_unhandled_exceptions_are_sanitized_and_traced(tmp_path):
    db_path = tmp_path / "error_test.db"
    engine = create_engine(
        f"sqlite:///{db_path}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    error_app = create_app(enabled_modules="auth")

    def override_get_db():
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    error_app.dependency_overrides[get_db] = override_get_db

    @error_app.get("/boom")
    def boom():
        raise RuntimeError("unexpected failure")

    with TestClient(error_app, raise_server_exceptions=False) as error_client:
        response = error_client.get("/boom")
        assert response.status_code == 500
        assert response.json()["detail"] == "Internal server error"
        assert response.headers["X-Request-ID"]
        assert response.json()["request_id"] == response.headers["X-Request-ID"]

    error_app.dependency_overrides.clear()
