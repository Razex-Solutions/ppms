from datetime import date, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from pathlib import Path

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
    assert expense_response.json()["status"] == "approved"

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

    profit_summary = test_client.get(
        "/accounting/profit-summary",
        params={"from_date": report_date, "to_date": "2100-01-01"},
        headers=manager_headers,
    )
    assert profit_summary.status_code == 200, profit_summary.text
    profit_json = profit_summary.json()
    assert profit_json["station_id"] == data["station_a_id"]
    assert profit_json["total_sales"] == 50
    assert profit_json["total_purchase_cost"] == 100
    assert profit_json["total_expenses"] == 15
    assert profit_json["net_profit"] == -65

    report_definition = test_client.post(
        "/report-definitions/",
        headers=manager_headers,
        json={
            "name": "Month End Ops",
            "report_type": "profit_summary",
            "station_id": data["station_a_id"],
            "filters": {
                "report_date": report_date,
                "from_date": report_date,
                "to_date": "2100-01-01",
            },
        },
    )
    assert report_definition.status_code == 200, report_definition.text
    definition_json = report_definition.json()
    assert definition_json["name"] == "Month End Ops"
    assert definition_json["filters"]["report_date"] == report_date

    report_definitions = test_client.get(
        "/report-definitions/",
        headers=manager_headers,
    )
    assert report_definitions.status_code == 200, report_definitions.text
    assert any(item["id"] == definition_json["id"] for item in report_definitions.json())


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
    assert local_expense.json()["status"] == "approved"

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


def test_expense_approval_workflow_controls_financial_reporting_for_pending_records(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    accountant_headers = login(test_client, "accountant", "accountant123")
    manager_headers = login(test_client, "manager", "manager123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    db = session_local()
    try:
        from app.models.expense import Expense
        from app.models.user import User

        manager = db.query(User).filter(User.username == "manager").first()
        pending_expense = Expense(
            title="Pending Expense",
            category="Ops",
            amount=25,
            station_id=data["station_a_id"],
            status="pending",
            submitted_by_user_id=manager.id if manager else None,
        )
        db.add(pending_expense)
        db.commit()
        db.refresh(pending_expense)
        expense_id = pending_expense.id
        report_date = pending_expense.created_at.date().isoformat()
    finally:
        db.close()

    pending_report = test_client.get(
        "/reports/daily-closing",
        params={"report_date": report_date},
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
        params={"report_date": report_date},
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
    assert expense_response.json()["status"] == "approved"

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
    assert expense_response.json()["status"] == "approved"

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


def test_notification_preferences_and_financial_documents(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")
    accountant_headers = login(test_client, "accountant", "accountant123")
    admin_headers = login(test_client, "admin", "admin123")

    pref_response = test_client.put(
        "/notifications/preferences/report_export.completed",
        headers=accountant_headers,
        json={
            "event_type": "report_export.completed",
            "in_app_enabled": True,
            "email_enabled": True,
            "sms_enabled": False,
            "whatsapp_enabled": False,
        },
    )
    assert pref_response.status_code == 200, pref_response.text
    assert pref_response.json()["email_enabled"] is True

    preset_list = test_client.get("/invoice-profiles/compliance-presets", headers=manager_headers)
    assert preset_list.status_code == 200, preset_list.text
    assert any(item["code"] == "PK-DEFAULT" for item in preset_list.json()["items"])

    profile_response = test_client.put(
        f"/invoice-profiles/{data['station_a_id']}",
        headers=manager_headers,
        json={
            "business_name": "My Pump Pvt Ltd",
            "legal_name": "My Pump Private Limited",
            "logo_url": "https://example.com/logo.png",
            "registration_no": "REG-4455",
            "tax_registration_no": "TAX-7788",
            "tax_label_1": "NTN",
            "tax_value_1": "1234567-8",
            "tax_label_2": "GST",
            "tax_value_2": "GST-9988",
            "default_tax_rate": 18,
            "tax_inclusive": False,
            "contact_email": "billing@mypump.test",
            "contact_phone": "03001234567",
            "footer_text": "Thank you for your business",
            "invoice_prefix": "MPP",
            "invoice_series": "2026",
            "invoice_number_width": 5,
            "payment_terms": "Payment due within 7 days",
            "sale_invoice_notes": "Keep this invoice for tax record.",
        },
    )
    assert profile_response.status_code == 200, profile_response.text
    assert profile_response.json()["invoice_prefix"] == "MPP"

    preset_apply = test_client.post(
        f"/invoice-profiles/{data['station_a_id']}/apply-preset",
        headers=manager_headers,
        params={"preset_code": "PK-DEFAULT"},
    )
    assert preset_apply.status_code == 200, preset_apply.text
    assert preset_apply.json()["compliance_mode"] == "regional_strict"
    assert preset_apply.json()["currency_code"] == "PKR"

    invalid_profile_response = test_client.put(
        f"/invoice-profiles/{data['station_a_id']}",
        headers=manager_headers,
        json={
            "business_name": "Strict Pump",
            "legal_name": None,
            "logo_url": None,
            "registration_no": None,
            "tax_registration_no": "GST-7788",
            "tax_label_1": "GST",
            "tax_value_1": None,
            "tax_label_2": None,
            "tax_value_2": None,
            "default_tax_rate": 18,
            "tax_inclusive": False,
            "region_code": "PK",
            "currency_code": "PKR",
            "compliance_mode": "regional_strict",
            "enforce_tax_registration": True,
            "contact_email": None,
            "contact_phone": None,
            "footer_text": None,
            "invoice_prefix": "SP",
            "invoice_series": None,
            "invoice_number_width": 6,
            "payment_terms": None,
            "sale_invoice_notes": None,
        },
    )
    assert invalid_profile_response.status_code == 400

    db = session_local()
    try:
        from app.models.customer import Customer
        from app.models.supplier import Supplier

        customer = db.query(Customer).filter(Customer.id == data["customer_id"]).first()
        supplier = db.query(Supplier).filter(Supplier.code == "SUP-A").first()
        customer.outstanding_balance = 200
        supplier.payable_balance = 150
        db.commit()
        supplier_id = supplier.id
    finally:
        db.close()

    customer_payment = test_client.post(
        "/customer-payments/",
        headers=accountant_headers,
        json={
            "customer_id": data["customer_id"],
            "station_id": data["station_a_id"],
            "amount": 50,
            "payment_method": "bank",
            "reference_no": "RCPT-1",
        },
    )
    assert customer_payment.status_code == 200, customer_payment.text
    customer_payment_id = customer_payment.json()["id"]

    supplier_payment = test_client.post(
        "/supplier-payments/",
        headers=accountant_headers,
        json={
            "supplier_id": supplier_id,
            "station_id": data["station_a_id"],
            "amount": 40,
            "payment_method": "bank",
            "reference_no": "VCHR-1",
        },
    )
    assert supplier_payment.status_code == 200, supplier_payment.text
    supplier_payment_id = supplier_payment.json()["id"]

    customer_receipt = test_client.get(
        f"/financial-documents/customer-payments/{customer_payment_id}",
        headers=accountant_headers,
    )
    assert customer_receipt.status_code == 200, customer_receipt.text
    assert "My Pump Private Limited" in customer_receipt.json()["rendered_html"]
    assert "NTN" in customer_receipt.json()["rendered_html"]
    assert customer_receipt.json()["document_number"].startswith("MPP-2026-CP-")

    supplier_voucher = test_client.get(
        f"/financial-documents/supplier-payments/{supplier_payment_id}",
        headers=accountant_headers,
    )
    assert supplier_voucher.status_code == 200, supplier_voucher.text
    assert supplier_voucher.json()["document_number"].startswith("MPP-2026-SP-")

    fuel_sale = test_client.post(
        "/fuel-sales/",
        headers=login(test_client, "operator", "operator123"),
        json={
            "nozzle_id": data["nozzle_id"],
            "station_id": data["station_a_id"],
            "fuel_type_id": data["fuel_type_id"],
            "customer_id": data["customer_id"],
            "closing_meter": 1008,
            "rate_per_liter": 10,
            "sale_type": "credit",
        },
    )
    assert fuel_sale.status_code == 200, fuel_sale.text
    fuel_sale_id = fuel_sale.json()["id"]

    sale_invoice = test_client.get(
        f"/financial-documents/fuel-sales/{fuel_sale_id}",
        headers=accountant_headers,
    )
    assert sale_invoice.status_code == 200, sale_invoice.text
    assert sale_invoice.json()["document_number"].startswith("MPP-2026-FS-")
    assert "Fuel Sale Invoice" in sale_invoice.json()["rendered_html"]
    assert "GST" in sale_invoice.json()["rendered_html"] or "NTN" in sale_invoice.json()["rendered_html"]
    assert "Payment due within 7 days" in sale_invoice.json()["rendered_html"]
    assert "Total: 94.40" in sale_invoice.json()["rendered_html"]
    assert sale_invoice.json()["compliance_context"]["currency_code"] == "PKR"
    assert sale_invoice.json()["machine_payload"]["schema_version"] == "ppms.einvoice.v1"

    sale_einvoice_payload = test_client.get(
        f"/financial-documents/fuel-sales/{fuel_sale_id}/einvoice",
        headers=accountant_headers,
    )
    assert sale_einvoice_payload.status_code == 200, sale_einvoice_payload.text
    assert sale_einvoice_payload.json()["payload"]["seller"]["region_code"] == "PK"
    assert sale_einvoice_payload.json()["payload"]["totals"]["grand_total"] == 94.4

    sale_einvoice_xml = test_client.get(
        f"/financial-documents/fuel-sales/{fuel_sale_id}/einvoice.xml",
        headers=accountant_headers,
    )
    assert sale_einvoice_xml.status_code == 200, sale_einvoice_xml.text
    assert sale_einvoice_xml.headers["content-type"].startswith("application/xml")
    assert "PPMSEInvoice" in sale_einvoice_xml.text
    assert "Fuel Sale Invoice" not in sale_einvoice_xml.text

    customer_receipt_pdf = test_client.get(
        f"/financial-documents/customer-payments/{customer_payment_id}/pdf",
        headers=accountant_headers,
    )
    assert customer_receipt_pdf.status_code == 200, customer_receipt_pdf.text
    assert customer_receipt_pdf.headers["content-type"].startswith("application/pdf")
    assert customer_receipt_pdf.content.startswith(b"%PDF")

    supplier_ledger_pdf = test_client.get(
        f"/financial-documents/supplier-ledgers/{supplier_id}/pdf?station_id={data['station_a_id']}",
        headers=accountant_headers,
    )
    assert supplier_ledger_pdf.status_code == 200, supplier_ledger_pdf.text
    assert supplier_ledger_pdf.headers["content-type"].startswith("application/pdf")
    assert supplier_ledger_pdf.content.startswith(b"%PDF")

    sale_invoice_pdf = test_client.get(
        f"/financial-documents/fuel-sales/{fuel_sale_id}/pdf",
        headers=accountant_headers,
    )
    assert sale_invoice_pdf.status_code == 200, sale_invoice_pdf.text
    assert sale_invoice_pdf.headers["content-type"].startswith("application/pdf")
    assert sale_invoice_pdf.content.startswith(b"%PDF")

    customer_dispatch = test_client.post(
        f"/financial-documents/customer-payments/{customer_payment_id}/send",
        headers=accountant_headers,
        json={"channel": "email", "format": "pdf"},
    )
    assert customer_dispatch.status_code == 200, customer_dispatch.text
    assert customer_dispatch.json()["status"] == "sent"

    supplier_dispatch = test_client.post(
        f"/financial-documents/supplier-ledgers/{supplier_id}/send?station_id={data['station_a_id']}",
        headers=accountant_headers,
        json={"channel": "whatsapp", "recipient_contact": "03009998888"},
    )
    assert supplier_dispatch.status_code == 200, supplier_dispatch.text
    assert supplier_dispatch.json()["status"] == "sent"

    sale_dispatch = test_client.post(
        f"/financial-documents/fuel-sales/{fuel_sale_id}/send",
        headers=accountant_headers,
        json={"channel": "print", "format": "pdf"},
    )
    assert sale_dispatch.status_code == 200, sale_dispatch.text
    assert sale_dispatch.json()["status"] == "sent"

    dispatch_list = test_client.get("/financial-documents/dispatches", headers=accountant_headers)
    assert dispatch_list.status_code == 200, dispatch_list.text
    assert len(dispatch_list.json()) >= 3

    export_response = test_client.post(
        "/report-exports/",
        headers=accountant_headers,
        json={"report_type": "customer_balances", "format": "csv"},
    )
    assert export_response.status_code == 200, export_response.text

    summary_response = test_client.get("/notifications/summary", headers=accountant_headers)
    assert summary_response.status_code == 200
    assert summary_response.json()["total"] >= 1

    deliveries_response = test_client.get("/notifications/deliveries", headers=accountant_headers)
    assert deliveries_response.status_code == 200, deliveries_response.text
    assert any(delivery["channel"] == "email" for delivery in deliveries_response.json())


def test_notification_delivery_retry_flow(client, monkeypatch):
    test_client, session_local = client
    seed_base_data(session_local)
    accountant_headers = login(test_client, "accountant", "accountant123")

    pref_response = test_client.put(
        "/notifications/preferences/report_export.completed",
        headers=accountant_headers,
        json={
            "event_type": "report_export.completed",
            "in_app_enabled": True,
            "email_enabled": True,
            "sms_enabled": False,
            "whatsapp_enabled": False,
        },
    )
    assert pref_response.status_code == 200, pref_response.text

    monkeypatch.setattr("app.services.notifications.deliver_email", lambda **kwargs: ("failed", "smtp unavailable"))

    export_response = test_client.post(
        "/report-exports/",
        headers=accountant_headers,
        json={"report_type": "customer_balances", "format": "csv"},
    )
    assert export_response.status_code == 200, export_response.text

    deliveries_response = test_client.get("/notifications/deliveries", headers=accountant_headers)
    assert deliveries_response.status_code == 200, deliveries_response.text
    email_delivery = next(delivery for delivery in deliveries_response.json() if delivery["channel"] == "email")
    assert email_delivery["status"] == "retrying"
    assert email_delivery["attempts_count"] == 1
    assert email_delivery["next_retry_at"] is not None

    monkeypatch.setattr("app.services.notifications.deliver_email", lambda **kwargs: ("sent", None))

    retry_response = test_client.post(
        f"/notifications/deliveries/{email_delivery['id']}/retry",
        headers=accountant_headers,
    )
    assert retry_response.status_code == 200, retry_response.text
    assert retry_response.json()["status"] == "delivered"
    assert retry_response.json()["attempts_count"] == 2
    assert retry_response.json()["processed_at"] is not None


def test_financial_document_dispatch_retry_flow(client, monkeypatch):
    test_client, session_local = client
    data = seed_base_data(session_local)
    accountant_headers = login(test_client, "accountant", "accountant123")

    db = session_local()
    try:
        from app.models.customer import Customer

        customer = db.query(Customer).filter(Customer.id == data["customer_id"]).first()
        customer.outstanding_balance = 120
        db.commit()
    finally:
        db.close()

    customer_payment = test_client.post(
        "/customer-payments/",
        headers=accountant_headers,
        json={
            "customer_id": data["customer_id"],
            "station_id": data["station_a_id"],
            "amount": 30,
            "payment_method": "cash",
            "reference_no": "RETRY-1",
        },
    )
    assert customer_payment.status_code == 200, customer_payment.text
    customer_payment_id = customer_payment.json()["id"]

    monkeypatch.setattr("app.services.financial_documents.deliver_email", lambda **kwargs: ("failed", "provider timeout"))

    dispatch_response = test_client.post(
        f"/financial-documents/customer-payments/{customer_payment_id}/send",
        headers=accountant_headers,
        json={"channel": "email", "format": "pdf"},
    )
    assert dispatch_response.status_code == 200, dispatch_response.text
    assert dispatch_response.json()["status"] == "retrying"
    assert dispatch_response.json()["output_format"] == "pdf"
    assert dispatch_response.json()["attempts_count"] == 1
    assert dispatch_response.json()["next_retry_at"] is not None

    monkeypatch.setattr("app.services.financial_documents.deliver_email", lambda **kwargs: ("sent", None))

    retry_response = test_client.post(
        f"/financial-documents/dispatches/{dispatch_response.json()['id']}/retry",
        headers=accountant_headers,
    )
    assert retry_response.status_code == 200, retry_response.text
    assert retry_response.json()["status"] == "sent"
    assert retry_response.json()["attempts_count"] == 2
    assert retry_response.json()["processed_at"] is not None


def test_process_due_notification_deliveries_endpoint(client, monkeypatch):
    test_client, session_local = client
    seed_base_data(session_local)
    accountant_headers = login(test_client, "accountant", "accountant123")
    admin_headers = login(test_client, "admin", "admin123")

    pref_response = test_client.put(
        "/notifications/preferences/report_export.completed",
        headers=accountant_headers,
        json={
            "event_type": "report_export.completed",
            "in_app_enabled": True,
            "email_enabled": True,
            "sms_enabled": False,
            "whatsapp_enabled": False,
        },
    )
    assert pref_response.status_code == 200, pref_response.text

    monkeypatch.setattr("app.services.notifications.deliver_email", lambda **kwargs: ("failed", "temporary email failure"))

    export_response = test_client.post(
        "/report-exports/",
        headers=accountant_headers,
        json={"report_type": "customer_balances", "format": "csv"},
    )
    assert export_response.status_code == 200, export_response.text

    deliveries_response = test_client.get("/notifications/deliveries", headers=accountant_headers)
    assert deliveries_response.status_code == 200, deliveries_response.text
    email_delivery = next(delivery for delivery in deliveries_response.json() if delivery["channel"] == "email")
    assert email_delivery["status"] == "retrying"

    db = session_local()
    try:
        from app.core.time import utc_now
        from app.models.notification_delivery import NotificationDelivery

        delivery = db.query(NotificationDelivery).filter(NotificationDelivery.id == email_delivery["id"]).first()
        delivery.next_retry_at = utc_now() - timedelta(minutes=1)
        db.commit()
    finally:
        db.close()

    monkeypatch.setattr("app.services.notifications.deliver_email", lambda **kwargs: ("sent", None))

    process_response = test_client.post("/notifications/deliveries/process-due", headers=admin_headers)
    assert process_response.status_code == 200, process_response.text
    assert process_response.json()["processed"] >= 1

    refreshed_deliveries = test_client.get("/notifications/deliveries", headers=accountant_headers)
    assert refreshed_deliveries.status_code == 200, refreshed_deliveries.text
    refreshed_email_delivery = next(delivery for delivery in refreshed_deliveries.json() if delivery["id"] == email_delivery["id"])
    assert refreshed_email_delivery["status"] == "delivered"
    assert refreshed_email_delivery["attempts_count"] == 2


def test_process_due_financial_document_dispatches_endpoint(client, monkeypatch):
    test_client, session_local = client
    data = seed_base_data(session_local)
    accountant_headers = login(test_client, "accountant", "accountant123")
    admin_headers = login(test_client, "admin", "admin123")

    db = session_local()
    try:
        from app.models.customer import Customer

        customer = db.query(Customer).filter(Customer.id == data["customer_id"]).first()
        customer.outstanding_balance = 180
        db.commit()
    finally:
        db.close()

    customer_payment = test_client.post(
        "/customer-payments/",
        headers=accountant_headers,
        json={
            "customer_id": data["customer_id"],
            "station_id": data["station_a_id"],
            "amount": 25,
            "payment_method": "bank",
            "reference_no": "QUEUE-1",
        },
    )
    assert customer_payment.status_code == 200, customer_payment.text
    customer_payment_id = customer_payment.json()["id"]

    monkeypatch.setattr("app.services.financial_documents.deliver_email", lambda **kwargs: ("failed", "mail gateway down"))

    dispatch_response = test_client.post(
        f"/financial-documents/customer-payments/{customer_payment_id}/send",
        headers=accountant_headers,
        json={"channel": "email", "format": "pdf"},
    )
    assert dispatch_response.status_code == 200, dispatch_response.text
    assert dispatch_response.json()["status"] == "retrying"

    db = session_local()
    try:
        from app.core.time import utc_now
        from app.models.financial_document_dispatch import FinancialDocumentDispatch

        dispatch = db.query(FinancialDocumentDispatch).filter(FinancialDocumentDispatch.id == dispatch_response.json()["id"]).first()
        dispatch.next_retry_at = utc_now() - timedelta(minutes=1)
        db.commit()
    finally:
        db.close()

    monkeypatch.setattr("app.services.financial_documents.deliver_email", lambda **kwargs: ("sent", None))

    process_response = test_client.post("/financial-documents/dispatches/process-due", headers=admin_headers)
    assert process_response.status_code == 200, process_response.text
    assert process_response.json()["processed"] >= 1

    dispatches_response = test_client.get("/financial-documents/dispatches", headers=accountant_headers)
    assert dispatches_response.status_code == 200, dispatches_response.text
    refreshed_dispatch = next(dispatch for dispatch in dispatches_response.json() if dispatch["id"] == dispatch_response.json()["id"])
    assert refreshed_dispatch["status"] == "sent"
    assert refreshed_dispatch["attempts_count"] == 2


def test_online_api_hooks_support_catalog_diagnostics_and_inbound_capture(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    catalog_response = test_client.get("/online-api-hooks/event-types", headers=head_office_headers)
    assert catalog_response.status_code == 200, catalog_response.text
    assert "report_export.completed" in catalog_response.json()["items"]

    hook_response = test_client.post(
        f"/online-api-hooks/{data['organization_id']}",
        headers=head_office_headers,
        json={
            "name": "erp-feed",
            "event_type": "report_export.completed",
            "target_url": "https://example.com/hooks/report-export",
            "auth_type": "hmac_sha256",
            "secret_key": "shared-secret",
            "is_active": True,
        },
    )
    assert hook_response.status_code == 200, hook_response.text
    hook_id = hook_response.json()["id"]
    assert hook_response.json()["signature_header"] == "X-PPMS-Signature"

    ping_response = test_client.post(
        f"/online-api-hooks/item/{hook_id}/ping",
        headers=head_office_headers,
        json={"payload": {"event": "report_export.completed", "job_id": 1}},
    )
    assert ping_response.status_code == 200, ping_response.text
    assert ping_response.json()["status"] == "sent"

    inbound_rejected = test_client.post(
        f"/online-api-hooks/inbound/{data['organization_id']}/erp-feed",
        headers={"X-PPMS-Event-Type": "report_export.completed", "X-PPMS-Signature": "sha256=bad"},
        json={"event_type": "report_export.completed", "job_id": 2},
    )
    assert inbound_rejected.status_code == 401

    inbound_accepted = test_client.post(
        f"/online-api-hooks/inbound/{data['organization_id']}/erp-feed",
        headers={"X-PPMS-Event-Type": "report_export.completed", "X-PPMS-Integration-Key": "shared-secret"},
        json={"event_type": "report_export.completed", "job_id": 3},
    )
    assert inbound_accepted.status_code == 200, inbound_accepted.text

    inbound_list = test_client.get(
        f"/online-api-hooks/{data['organization_id']}/inbound-events",
        headers=head_office_headers,
    )
    assert inbound_list.status_code == 200, inbound_list.text
    assert len(inbound_list.json()) >= 2
    assert any(item["status"] == "received" for item in inbound_list.json())
    assert any(item["status"] == "rejected" for item in inbound_list.json())

    diagnostics_response = test_client.get(
        f"/online-api-hooks/{data['organization_id']}/diagnostics",
        headers=head_office_headers,
    )
    assert diagnostics_response.status_code == 200, diagnostics_response.text
    assert diagnostics_response.json()["hook_count"] >= 1
    assert diagnostics_response.json()["inbound_event_count"] >= 2


def test_delivery_dead_letter_and_diagnostics_views(client, monkeypatch):
    test_client, session_local = client
    data = seed_base_data(session_local)
    accountant_headers = login(test_client, "accountant", "accountant123")

    pref_response = test_client.put(
        "/notifications/preferences/report_export.completed",
        headers=accountant_headers,
        json={
            "event_type": "report_export.completed",
            "in_app_enabled": True,
            "email_enabled": True,
            "sms_enabled": False,
            "whatsapp_enabled": False,
        },
    )
    assert pref_response.status_code == 200, pref_response.text

    monkeypatch.setattr("app.services.notifications.deliver_email", lambda **kwargs: ("failed", "smtp unavailable"))
    monkeypatch.setattr("app.services.financial_documents.deliver_email", lambda **kwargs: ("failed", "mail unavailable"))
    monkeypatch.setattr("app.services.notifications.should_retry", lambda status, attempts: False)
    monkeypatch.setattr("app.services.financial_documents.should_retry", lambda status, attempts: False)

    export_response = test_client.post(
        "/report-exports/",
        headers=accountant_headers,
        json={"report_type": "customer_balances", "format": "csv"},
    )
    assert export_response.status_code == 200, export_response.text

    db = session_local()
    try:
        from app.models.customer import Customer

        customer = db.query(Customer).filter(Customer.id == data["customer_id"]).first()
        customer.outstanding_balance = 100
        db.commit()
    finally:
        db.close()

    customer_payment = test_client.post(
        "/customer-payments/",
        headers=accountant_headers,
        json={
            "customer_id": data["customer_id"],
            "station_id": data["station_a_id"],
            "amount": 20,
            "payment_method": "cash",
            "reference_no": "DL-1",
        },
    )
    assert customer_payment.status_code == 200, customer_payment.text

    dispatch_response = test_client.post(
        f"/financial-documents/customer-payments/{customer_payment.json()['id']}/send",
        headers=accountant_headers,
        json={"channel": "email", "format": "pdf"},
    )
    assert dispatch_response.status_code == 200, dispatch_response.text
    assert dispatch_response.json()["status"] == "failed"

    notification_dead_letter = test_client.get("/notifications/deliveries/dead-letter", headers=accountant_headers)
    assert notification_dead_letter.status_code == 200, notification_dead_letter.text
    assert any(item["status"] == "failed" for item in notification_dead_letter.json())

    notification_diag = test_client.get("/notifications/deliveries/diagnostics", headers=accountant_headers)
    assert notification_diag.status_code == 200, notification_diag.text
    assert notification_diag.json()["dead_letter"] >= 1

    document_dead_letter = test_client.get("/financial-documents/dispatches/dead-letter", headers=accountant_headers)
    assert document_dead_letter.status_code == 200, document_dead_letter.text
    assert any(item["status"] == "failed" for item in document_dead_letter.json())

    document_diag = test_client.get("/financial-documents/dispatches/diagnostics", headers=accountant_headers)
    assert document_diag.status_code == 200, document_diag.text
    assert document_diag.json()["dead_letter"] >= 1


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


def test_maintenance_snapshot_backup_restore_and_integrity(client, monkeypatch):
    test_client, session_local = client
    data = seed_base_data(session_local)
    admin_headers = login(test_client, "admin", "admin123")

    db = session_local()
    db_path = Path(db.bind.url.database).resolve()
    db.close()
    backup_dir = db_path.parent / "ops_backups"

    monkeypatch.setattr("app.services.maintenance.DATABASE_URL", f"sqlite:///{db_path}")
    monkeypatch.setattr("app.services.maintenance.BACKUP_DIRECTORY", str(backup_dir))
    monkeypatch.setattr("app.services.maintenance.BACKUP_RETENTION_COUNT", 5)
    monkeypatch.setattr("app.main.DATABASE_URL", f"sqlite:///{db_path}")
    monkeypatch.setattr("app.main.BACKUP_DIRECTORY", str(backup_dir))

    snapshot_response = test_client.get("/maintenance/snapshot", headers=admin_headers)
    assert snapshot_response.status_code == 200, snapshot_response.text
    assert snapshot_response.json()["database_exists"] is True
    assert snapshot_response.json()["database_integrity"]["status"] == "ok"

    backup_response = test_client.post("/maintenance/backup", headers=admin_headers)
    assert backup_response.status_code == 200, backup_response.text
    backup_name = Path(backup_response.json()["backup_path"]).name

    integrity_response = test_client.get("/maintenance/integrity", headers=admin_headers)
    assert integrity_response.status_code == 200, integrity_response.text
    assert integrity_response.json()["status"] == "ok"

    db = session_local()
    try:
        from app.models.customer import Customer

        extra_customer = Customer(
            name="Restore Candidate",
            code="RESTORE-1",
            customer_type="company",
            phone="000",
            address="Restore Lane",
            credit_limit=100,
            outstanding_balance=0,
            station_id=data["station_a_id"],
        )
        db.add(extra_customer)
        db.commit()
    finally:
        db.close()

    restore_response = test_client.post(
        "/maintenance/restore",
        headers=admin_headers,
        json={"backup_name": backup_name},
    )
    assert restore_response.status_code == 200, restore_response.text

    db = session_local()
    try:
        from app.models.customer import Customer

        restored_customer = db.query(Customer).filter(Customer.code == "RESTORE-1").first()
        assert restored_customer is None
    finally:
        db.close()


def test_non_admin_cannot_use_maintenance_endpoints(client, monkeypatch):
    test_client, session_local = client
    seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")

    db = session_local()
    db_path = Path(db.bind.url.database).resolve()
    db.close()
    backup_dir = db_path.parent / "ops_backups_forbidden"

    monkeypatch.setattr("app.services.maintenance.DATABASE_URL", f"sqlite:///{db_path}")
    monkeypatch.setattr("app.services.maintenance.BACKUP_DIRECTORY", str(backup_dir))

    assert test_client.get("/maintenance/snapshot", headers=manager_headers).status_code == 403
    assert test_client.get("/maintenance/integrity", headers=manager_headers).status_code == 403
    assert test_client.post("/maintenance/backup", headers=manager_headers).status_code == 403
