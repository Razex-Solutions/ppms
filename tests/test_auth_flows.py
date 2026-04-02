from app.models.user import User

from tests.conftest import login, seed_base_data


def test_user_can_change_own_password_and_log_in_with_new_password(client):
    test_client, session_local = client
    seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")

    bad_change = test_client.post(
        "/auth/change-password",
        headers=operator_headers,
        json={"current_password": "wrong-password", "new_password": "operator456"},
    )
    assert bad_change.status_code == 400

    change_response = test_client.post(
        "/auth/change-password",
        headers=operator_headers,
        json={"current_password": "operator123", "new_password": "operator456"},
    )
    assert change_response.status_code == 200, change_response.text

    old_login = test_client.post("/auth/login", json={"username": "operator", "password": "operator123"})
    assert old_login.status_code == 401

    new_login = test_client.post("/auth/login", json={"username": "operator", "password": "operator456"})
    assert new_login.status_code == 200


def test_admin_can_reset_password_but_non_admin_cannot(client):
    test_client, session_local = client
    seed_base_data(session_local)
    admin_headers = login(test_client, "admin", "admin123")
    operator_headers = login(test_client, "operator", "operator123")

    db = session_local()
    try:
        manager = db.query(User).filter(User.username == "manager").first()
        manager_id = manager.id
    finally:
        db.close()

    forbidden_reset = test_client.post(
        f"/auth/admin-reset-password/{manager_id}",
        headers=operator_headers,
        json={"new_password": "manager456"},
    )
    assert forbidden_reset.status_code == 403

    reset_response = test_client.post(
        f"/auth/admin-reset-password/{manager_id}",
        headers=admin_headers,
        json={"new_password": "manager456"},
    )
    assert reset_response.status_code == 200, reset_response.text

    old_login = test_client.post("/auth/login", json={"username": "manager", "password": "manager123"})
    assert old_login.status_code == 401

    new_login = test_client.post("/auth/login", json={"username": "manager", "password": "manager456"})
    assert new_login.status_code == 200
