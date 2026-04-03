from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import create_app

from tests.conftest import login, seed_base_data


def test_module_toggle_can_disable_routes(tmp_path):
    db_path = tmp_path / "toggle_test.db"
    engine = create_engine(
        f"sqlite:///{db_path}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    module_app = create_app(enabled_modules="auth,customers")

    def override_get_db():
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    module_app.dependency_overrides[get_db] = override_get_db

    with TestClient(module_app) as test_client:
        health = test_client.get("/health")
        assert health.status_code == 200
        assert "customers" in health.json()["enabled_modules"]
        assert "expenses" not in health.json()["enabled_modules"]

        disabled = test_client.get("/expenses/")
        assert disabled.status_code == 404

    module_app.dependency_overrides.clear()


def test_master_data_delete_is_blocked_when_history_exists(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    admin_headers = login(test_client, "admin", "admin123")
    manager_headers = login(test_client, "manager", "manager123")
    operator_headers = login(test_client, "operator", "operator123")

    sale_response = test_client.post(
        "/fuel-sales/",
        headers=operator_headers,
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
    assert sale_response.status_code == 200, sale_response.text

    db = session_local()
    try:
        from app.models.supplier import Supplier

        supplier = db.query(Supplier).filter(Supplier.code == "SUP-A").first()
        supplier.payable_balance = 50
        db.commit()
        supplier_id = supplier.id
    finally:
        db.close()

    supplier_payment_response = test_client.post(
        "/supplier-payments/",
        headers=admin_headers,
        json={
            "supplier_id": supplier_id,
            "station_id": data["station_a_id"],
            "amount": 20,
            "payment_method": "cash",
        },
    )
    assert supplier_payment_response.status_code == 200, supplier_payment_response.text

    customer_delete = test_client.delete(f"/customers/{data['customer_id']}", headers=manager_headers)
    assert customer_delete.status_code == 400

    supplier_delete = test_client.delete(f"/suppliers/{supplier_id}", headers=admin_headers)
    assert supplier_delete.status_code == 400

    tank_delete = test_client.delete(f"/tanks/{data['tank_id']}", headers=manager_headers)
    assert tank_delete.status_code == 400

    fuel_type_delete = test_client.delete(f"/fuel-types/{data['fuel_type_id']}", headers=admin_headers)
    assert fuel_type_delete.status_code == 400

    station_delete = test_client.delete(f"/stations/{data['station_a_id']}", headers=admin_headers)
    assert station_delete.status_code == 400


def test_admin_can_manage_organizations_and_station_ownership(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    admin_headers = login(test_client, "admin", "admin123")
    manager_headers = login(test_client, "manager", "manager123")

    forbidden_org_create = test_client.post(
        "/organizations/",
        headers=manager_headers,
        json={"name": "Forbidden Org", "code": "FORBID", "description": "Nope"},
    )
    assert forbidden_org_create.status_code == 403

    org_response = test_client.post(
        "/organizations/",
        headers=admin_headers,
        json={"name": "Org C", "code": "ORG-C", "description": "Secondary org"},
    )
    assert org_response.status_code == 200, org_response.text
    organization_id = org_response.json()["id"]

    station_response = test_client.post(
        "/stations/",
        headers=admin_headers,
        json={
            "name": "Station D",
            "code": "STD",
            "address": "Addr C",
            "city": "City C",
            "organization_id": organization_id,
            "is_head_office": True,
        },
    )
    assert station_response.status_code == 200, station_response.text
    assert station_response.json()["organization_id"] == organization_id
    assert station_response.json()["is_head_office"] is True

    duplicate_head_office = test_client.post(
        "/stations/",
        headers=admin_headers,
        json={
            "name": "Station D",
            "code": "STD",
            "address": "Addr D",
            "city": "City D",
            "organization_id": organization_id,
            "is_head_office": True,
        },
    )
    assert duplicate_head_office.status_code == 400

    org_stations = test_client.get(f"/stations/?organization_id={organization_id}", headers=admin_headers)
    assert org_stations.status_code == 200
    assert any(station["code"] == "STD" for station in org_stations.json())


def test_head_office_can_read_only_own_organization_users_and_stations(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    stations_response = test_client.get("/stations/", headers=head_office_headers)
    assert stations_response.status_code == 200, stations_response.text
    station_codes = {station["code"] for station in stations_response.json()}
    assert station_codes == {"STA", "STB"}

    forbidden_station = test_client.get(f"/stations/{data['station_c_id']}", headers=head_office_headers)
    assert forbidden_station.status_code == 403

    users_response = test_client.get("/users/", headers=head_office_headers)
    assert users_response.status_code == 200, users_response.text
    usernames = {user["username"] for user in users_response.json()}
    assert "headoffice" in usernames
    assert "manager" in usernames
    assert "foreignmanager" not in usernames

    admin_create_attempt = test_client.post(
        "/users/",
        headers=head_office_headers,
        json={
            "full_name": "Blocked User",
            "username": "blockeduser",
            "email": "blocked@example.com",
            "password": "blocked123",
            "role_id": 1,
            "station_id": data["station_a_id"],
        },
    )
    assert admin_create_attempt.status_code == 403

    organizations_response = test_client.get("/organizations/", headers=head_office_headers)
    assert organizations_response.status_code == 200, organizations_response.text
    assert [organization["code"] for organization in organizations_response.json()] == ["ORG-A"]

    allowed_organization = test_client.get(f"/organizations/{data['organization_id']}", headers=head_office_headers)
    assert allowed_organization.status_code == 200
    assert allowed_organization.json()["code"] == "ORG-A"

    forbidden_organization = test_client.get(
        f"/organizations/{data['foreign_organization_id']}",
        headers=head_office_headers,
    )
    assert forbidden_organization.status_code == 403


def test_head_office_can_manage_station_modules_per_station(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    station_modules = test_client.get(f"/station-modules/{data['station_a_id']}", headers=head_office_headers)
    assert station_modules.status_code == 200, station_modules.text
    assert any(module["module_name"] == "tanker_operations" and module["is_enabled"] for module in station_modules.json())

    disable_response = test_client.put(
        f"/station-modules/{data['station_a_id']}",
        headers=head_office_headers,
        json={"module_name": "tanker_operations", "is_enabled": False},
    )
    assert disable_response.status_code == 200, disable_response.text
    assert disable_response.json()["is_enabled"] is False

    forbidden_other_org = test_client.put(
        f"/station-modules/{data['station_c_id']}",
        headers=head_office_headers,
        json={"module_name": "tanker_operations", "is_enabled": False},
    )
    assert forbidden_other_org.status_code == 403


def test_permission_catalog_and_core_role_governance(client):
    test_client, session_local = client
    seed_base_data(session_local)
    admin_headers = login(test_client, "admin", "admin123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    me_response = test_client.get("/auth/me", headers=admin_headers)
    assert me_response.status_code == 200, me_response.text
    assert me_response.json()["role_name"] == "Admin"
    assert "users" in me_response.json()["permissions"]
    assert me_response.json()["role_summary"]["scope"] == "System-wide"

    catalog_response = test_client.get("/roles/permission-catalog", headers=head_office_headers)
    assert catalog_response.status_code == 200, catalog_response.text
    assert "Admin" in catalog_response.json()["core_roles"]
    assert "roles" in catalog_response.json()["permission_matrix"]

    manager_policy = test_client.get("/roles/permission-catalog/Manager", headers=head_office_headers)
    assert manager_policy.status_code == 200, manager_policy.text
    assert manager_policy.json()["role_name"] == "Manager"
    assert "fuel_sales" in manager_policy.json()["permissions"]

    db = session_local()
    try:
        from app.models.role import Role

        admin_role = db.query(Role).filter(Role.name == "Admin").first()
        admin_role_id = admin_role.id
    finally:
        db.close()

    rename_response = test_client.put(
        f"/roles/{admin_role_id}",
        headers=admin_headers,
        json={"name": "SuperAdmin"},
    )
    assert rename_response.status_code == 400

    delete_response = test_client.delete(f"/roles/{admin_role_id}", headers=admin_headers)
    assert delete_response.status_code == 400
