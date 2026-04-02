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


def test_validation_errors_include_request_id(client):
    test_client, _ = client

    response = test_client.post("/auth/login", json={"username": "admin"})

    assert response.status_code == 422
    assert response.headers["X-Request-ID"]
    assert response.json()["request_id"] == response.headers["X-Request-ID"]


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
