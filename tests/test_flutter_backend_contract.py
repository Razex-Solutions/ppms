from tests.conftest import login, seed_base_data


def _assert_keys(item: dict, keys: set[str], label: str):
    missing = keys - set(item.keys())
    assert not missing, f"{label} missing keys: {sorted(missing)}"


def test_flutter_contract_for_auth_dashboard_and_reference_lists(client):
    test_client, session_local = client
    data = seed_base_data(session_local)

    admin_headers = login(test_client, "admin", "admin123")
    operator_headers = login(test_client, "operator", "operator123")
    manager_headers = login(test_client, "manager", "manager123")

    auth_me = test_client.get("/auth/me", headers=admin_headers)
    assert auth_me.status_code == 200, auth_me.text
    _assert_keys(
        auth_me.json(),
        {
            "id",
            "username",
            "full_name",
            "station_id",
            "organization_id",
            "role_name",
            "permissions",
            "backend_enabled_modules",
            "effective_enabled_modules",
            "feature_flags",
        },
        "auth me",
    )
    assert "fuel_sales" in auth_me.json()["effective_enabled_modules"]
    assert auth_me.json()["feature_flags"]["meter_adjustments"] is True

    dashboard = test_client.get(
        f"/dashboard/?station_id={data['station_a_id']}",
        headers=operator_headers,
    )
    assert dashboard.status_code == 200, dashboard.text
    _assert_keys(
        dashboard.json(),
        {
            "sales",
            "expenses",
            "net_profit",
            "fuel_stock_liters",
            "receivables",
            "payables",
            "low_stock_alerts",
            "credit_limit_alerts",
            "tanker",
        },
        "dashboard",
    )
    _assert_keys(dashboard.json()["sales"], {"cash", "credit", "total"}, "dashboard sales")
    _assert_keys(
        dashboard.json()["tanker"],
        {"completed_trips", "net_profit"},
        "dashboard tanker",
    )

    stations = test_client.get("/stations/", headers=admin_headers)
    assert stations.status_code == 200, stations.text
    assert stations.json(), "stations list should not be empty"
    _assert_keys(stations.json()[0], {"id", "name", "code", "organization_id"}, "station")

    fuel_types = test_client.get("/fuel-types/", headers=admin_headers)
    assert fuel_types.status_code == 200, fuel_types.text
    _assert_keys(fuel_types.json()[0], {"id", "name", "description"}, "fuel type")

    tanks = test_client.get(
        f"/tanks/?station_id={data['station_a_id']}",
        headers=admin_headers,
    )
    assert tanks.status_code == 200, tanks.text
    _assert_keys(
        tanks.json()[0],
        {
            "id",
            "name",
            "code",
            "capacity",
            "current_volume",
            "low_stock_threshold",
            "fuel_type_id",
            "station_id",
        },
        "tank",
    )

    dispensers = test_client.get(
        f"/dispensers/?station_id={data['station_a_id']}",
        headers=admin_headers,
    )
    assert dispensers.status_code == 200, dispensers.text
    _assert_keys(
        dispensers.json()[0],
        {"id", "name", "code", "location", "station_id"},
        "dispenser",
    )

    nozzles = test_client.get(
        f"/nozzles/?station_id={data['station_a_id']}",
        headers=admin_headers,
    )
    assert nozzles.status_code == 200, nozzles.text
    _assert_keys(
        nozzles.json()[0],
        {
            "id",
            "name",
            "code",
            "meter_reading",
            "dispenser_id",
            "tank_id",
            "fuel_type_id",
        },
        "nozzle",
    )

    customers = test_client.get(
        f"/customers/?station_id={data['station_a_id']}",
        headers=operator_headers,
    )
    assert customers.status_code == 200, customers.text
    _assert_keys(
        customers.json()[0],
        {
            "id",
            "name",
            "code",
            "customer_type",
            "credit_limit",
            "outstanding_balance",
            "station_id",
        },
        "customer",
    )

    suppliers = test_client.get("/suppliers/", headers=admin_headers)
    assert suppliers.status_code == 200, suppliers.text
    _assert_keys(
        suppliers.json()[0],
        {"id", "name", "code", "phone", "address", "payable_balance"},
        "supplier",
    )


def test_flutter_contract_for_admin_setup_finance_and_governance_lists(client):
    test_client, session_local = client
    data = seed_base_data(session_local)

    admin_headers = login(test_client, "admin", "admin123")
    operator_headers = login(test_client, "operator", "operator123")
    manager_headers = login(test_client, "manager", "manager123")

    expense_response = test_client.post(
        "/expenses/",
        headers=manager_headers,
        json={
            "station_id": data["station_a_id"],
            "title": "Generator Fuel",
            "category": "utilities",
            "amount": 25,
            "notes": "Daily generator top-up",
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
            "quantity": 10,
            "rate_per_liter": 5,
        },
    )
    assert purchase_response.status_code == 200, purchase_response.text

    credit_override_response = test_client.post(
        f"/customers/{data['customer_id']}/request-credit-override",
        headers=manager_headers,
        json={"amount": 50, "reason": "Urgent dispatch"},
    )
    assert credit_override_response.status_code == 200, credit_override_response.text

    users = test_client.get(
        f"/users/?station_id={data['station_a_id']}",
        headers=admin_headers,
    )
    assert users.status_code == 200, users.text
    _assert_keys(
        users.json()[0],
        {
            "id",
            "username",
            "full_name",
            "email",
            "role_id",
            "station_id",
            "monthly_salary",
            "payroll_enabled",
        },
        "user",
    )

    invoice_profile = test_client.put(
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
    assert invoice_profile.status_code == 200, invoice_profile.text
    _assert_keys(
        invoice_profile.json(),
        {
            "station_id",
            "business_name",
            "legal_name",
            "default_tax_rate",
            "tax_inclusive",
            "region_code",
            "currency_code",
            "compliance_mode",
            "invoice_prefix",
            "invoice_series",
            "invoice_number_width",
        },
        "invoice profile",
    )

    expenses = test_client.get(
        f"/expenses/?station_id={data['station_a_id']}&status=approved",
        headers=operator_headers,
    )
    assert expenses.status_code == 200, expenses.text
    _assert_keys(
        expenses.json()[0],
        {"id", "title", "category", "amount", "status", "created_at"},
        "expense",
    )

    purchases = test_client.get(
        f"/purchases/?station_id={data['station_a_id']}",
        headers=operator_headers,
    )
    assert purchases.status_code == 200, purchases.text
    _assert_keys(
        purchases.json()[0],
        {
            "id",
            "supplier_id",
            "fuel_type_id",
            "tank_id",
            "quantity",
            "rate_per_liter",
            "total_amount",
            "status",
            "created_at",
            "reversal_request_status",
        },
        "purchase",
    )

    customers = test_client.get(
        f"/customers/?station_id={data['station_a_id']}",
        headers=operator_headers,
    )
    assert customers.status_code == 200, customers.text
    _assert_keys(
        customers.json()[0],
        {
            "id",
            "name",
            "code",
            "credit_override_requested_amount",
            "credit_override_status",
            "credit_limit",
        },
        "governance customer",
    )
