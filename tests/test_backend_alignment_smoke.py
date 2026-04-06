from sqlalchemy import inspect, text

from tests.conftest import login, seed_base_data


def test_database_schema_contains_core_backend_tables(client):
    _, session_local = client
    seed_base_data(session_local)

    db = session_local()
    try:
        inspector = inspect(db.get_bind())
        table_names = set(inspector.get_table_names())
        expected_tables = {
            "organizations",
            "organization_module_settings",
            "organization_subscriptions",
            "stations",
            "station_module_settings",
            "roles",
            "users",
            "auth_sessions",
            "fuel_types",
            "tanks",
            "dispensers",
            "nozzles",
            "meter_adjustment_events",
            "customers",
            "suppliers",
            "purchases",
            "fuel_sales",
            "expenses",
            "customer_payments",
            "supplier_payments",
            "shifts",
            "tank_dips",
            "audit_logs",
            "notifications",
            "notification_preferences",
            "notification_deliveries",
            "invoice_profiles",
            "document_templates",
            "financial_document_dispatches",
            "hardware_devices",
            "hardware_events",
            "tankers",
            "tanker_trips",
            "tanker_deliveries",
            "tanker_trip_expenses",
            "pos_products",
            "pos_sales",
            "pos_sale_items",
            "attendance_records",
            "payroll_runs",
            "payroll_lines",
            "fuel_price_history",
            "report_export_jobs",
            "subscription_plans",
            "online_api_hooks",
            "inbound_webhook_events",
        }
        missing_tables = expected_tables - table_names
        assert not missing_tables, f"Missing tables: {sorted(missing_tables)}"

        user_columns = {column["name"] for column in inspector.get_columns("users")}
        assert {"failed_login_attempts", "locked_until", "monthly_salary"} <= user_columns

        auth_session_columns = {
            column["name"] for column in inspector.get_columns("auth_sessions")
        }
        assert {"refresh_token_hash", "is_active", "expires_at", "revoked_at"} <= auth_session_columns

        hardware_columns = {
            column["name"] for column in inspector.get_columns("hardware_devices")
        }
        assert {"vendor_name", "protocol", "endpoint_url", "device_identifier"} <= hardware_columns
    finally:
        db.close()


def test_backend_alignment_smoke_for_major_routes(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    db = session_local()
    try:
        supplier_id = db.execute(
            text("SELECT id FROM suppliers WHERE code = 'SUP-A'"),
        ).scalar_one()
    finally:
        db.close()

    public_root = test_client.get("/")
    assert public_root.status_code == 200, public_root.text

    public_health = test_client.get("/health")
    assert public_health.status_code == 200, public_health.text

    public_openapi = test_client.get("/openapi.json")
    assert public_openapi.status_code == 200, public_openapi.text
    paths = set(public_openapi.json()["paths"].keys())
    for required_path in {
        "/auth/login",
        "/dashboard/",
        "/fuel-sales/",
        "/purchases/",
        "/customer-payments/",
        "/supplier-payments/",
        "/reports/daily-closing",
        "/maintenance/snapshot",
        "/attendance/",
        "/payroll/runs",
        "/hardware/devices",
        "/notifications/",
    }:
        assert required_path in paths

    admin_headers = login(test_client, "admin", "admin123")
    operator_headers = login(test_client, "operator", "operator123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    invoice_profile_put = test_client.put(
        f"/invoice-profiles/{data['station_a_id']}",
        headers=admin_headers,
        json={
            "business_name": "Station A Fuel",
            "legal_name": "Station A Fuel Pty",
            "registration_no": "REG-123",
            "tax_registration_no": "GST-456",
            "default_tax_rate": 15,
            "tax_inclusive": False,
            "region_code": "AU-NSW",
            "currency_code": "AUD",
            "compliance_mode": "standard",
            "enforce_tax_registration": False,
            "invoice_prefix": "STA",
            "invoice_series": "A",
            "invoice_number_width": 6,
            "payment_terms": "7 days",
            "footer_text": "Thank you",
            "sale_invoice_notes": "Drive safe",
        },
    )
    assert invoice_profile_put.status_code == 200, invoice_profile_put.text

    template_seed = test_client.post(
        f"/document-templates/{data['station_a_id']}/seed-defaults",
        headers=admin_headers,
    )
    assert template_seed.status_code == 200, template_seed.text

    route_checks = [
        ("auth me", "GET", "/auth/me", admin_headers),
        ("dashboard", "GET", f"/dashboard/?station_id={data['station_a_id']}", operator_headers),
        ("roles", "GET", "/roles/", admin_headers),
        ("permission catalog", "GET", "/roles/permission-catalog", admin_headers),
        ("organizations", "GET", "/organizations/", admin_headers),
        ("org modules", "GET", f"/organization-modules/{data['organization_id']}", admin_headers),
        ("stations", "GET", "/stations/", admin_headers),
        ("station modules", "GET", f"/station-modules/{data['station_a_id']}", admin_headers),
        ("users", "GET", f"/users/?station_id={data['station_a_id']}", admin_headers),
        ("fuel types", "GET", "/fuel-types/", admin_headers),
        ("fuel price history", "GET", f"/fuel-types/{data['fuel_type_id']}/price-history?station_id={data['station_a_id']}", admin_headers),
        ("tanks", "GET", f"/tanks/?station_id={data['station_a_id']}", admin_headers),
        ("dispensers", "GET", f"/dispensers/?station_id={data['station_a_id']}", admin_headers),
        ("nozzles", "GET", f"/nozzles/?station_id={data['station_a_id']}", admin_headers),
        ("customers", "GET", f"/customers/?station_id={data['station_a_id']}", operator_headers),
        ("suppliers", "GET", "/suppliers/", admin_headers),
        ("purchases", "GET", f"/purchases/?station_id={data['station_a_id']}", operator_headers),
        ("expenses", "GET", f"/expenses/?station_id={data['station_a_id']}", operator_headers),
        ("customer payments", "GET", "/customer-payments/", operator_headers),
        ("supplier payments", "GET", "/supplier-payments/", operator_headers),
        ("customer ledger", "GET", f"/ledger/customer/{data['customer_id']}", admin_headers),
        ("customer ledger summary", "GET", f"/ledger/customer/{data['customer_id']}/summary", admin_headers),
        ("supplier ledger", "GET", f"/ledger/supplier/{supplier_id}", admin_headers),
        ("supplier ledger summary", "GET", f"/ledger/supplier/{supplier_id}/summary", admin_headers),
        ("attendance", "GET", "/attendance/", admin_headers),
        ("payroll", "GET", "/payroll/runs", admin_headers),
        ("shifts", "GET", f"/shifts/?station_id={data['station_a_id']}", operator_headers),
        ("tank dips", "GET", f"/tank-dips/?station_id={data['station_a_id']}", operator_headers),
        ("audit logs", "GET", "/audit-logs/", admin_headers),
        ("notifications", "GET", "/notifications/", admin_headers),
        ("notification prefs", "GET", "/notifications/preferences", admin_headers),
        ("notification diagnostics", "GET", "/notifications/deliveries/diagnostics", admin_headers),
        ("reports daily closing", "GET", f"/reports/daily-closing?report_date=2026-04-04&station_id={data['station_a_id']}", admin_headers),
        ("reports stock movement", "GET", f"/reports/stock-movement?station_id={data['station_a_id']}", admin_headers),
        ("reports customer balances", "GET", f"/reports/customer-balances?station_id={data['station_a_id']}", admin_headers),
        ("reports supplier balances", "GET", f"/reports/supplier-balances?station_id={data['station_a_id']}", admin_headers),
        ("report exports", "GET", "/report-exports/", admin_headers),
        ("invoice profile", "GET", f"/invoice-profiles/{data['station_a_id']}", admin_headers),
        ("invoice presets", "GET", "/invoice-profiles/compliance-presets", admin_headers),
        ("document templates", "GET", f"/document-templates/{data['station_a_id']}", admin_headers),
        ("document placeholders", "GET", "/document-templates/placeholders/fuel_sale_invoice", admin_headers),
        ("maintenance snapshot", "GET", "/maintenance/snapshot", admin_headers),
        ("maintenance backups", "GET", "/maintenance/backups", admin_headers),
        ("maintenance integrity", "GET", "/maintenance/integrity", admin_headers),
        ("hardware devices", "GET", f"/hardware/devices?station_id={data['station_a_id']}", admin_headers),
        ("hardware events", "GET", f"/hardware/events?station_id={data['station_a_id']}", admin_headers),
        ("hardware vendors", "GET", "/hardware/vendors", admin_headers),
        ("tankers", "GET", f"/tankers/?station_id={data['station_a_id']}", admin_headers),
        ("tanker trips", "GET", f"/tankers/trips?station_id={data['station_a_id']}", admin_headers),
        ("pos products", "GET", f"/pos-products/?station_id={data['station_a_id']}", admin_headers),
        ("pos sales", "GET", f"/pos-sales/?station_id={data['station_a_id']}", admin_headers),
        ("saas plans", "GET", "/saas/plans", admin_headers),
        ("saas subscription", "GET", f"/saas/organizations/{data['organization_id']}/subscription", admin_headers),
        ("online hooks", "GET", f"/online-api-hooks/{data['organization_id']}", admin_headers),
        ("online hook event types", "GET", "/online-api-hooks/event-types", admin_headers),
        ("online hook diagnostics", "GET", f"/online-api-hooks/{data['organization_id']}/diagnostics", admin_headers),
        ("online hook inbound events", "GET", f"/online-api-hooks/{data['organization_id']}/inbound-events", admin_headers),
        ("head office stations", "GET", "/stations/", head_office_headers),
        ("head office users", "GET", "/users/", head_office_headers),
    ]

    for label, method, url, headers in route_checks:
        response = test_client.request(method, url, headers=headers)
        assert response.status_code == 200, f"{label} failed: {response.status_code} {response.text}"
