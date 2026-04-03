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


def test_refresh_logout_and_session_listing_work(client):
    test_client, session_local = client
    seed_base_data(session_local)

    login_response = test_client.post("/auth/login", json={"username": "operator", "password": "operator123"})
    assert login_response.status_code == 200, login_response.text
    login_payload = login_response.json()
    headers = {"Authorization": f"Bearer {login_payload['access_token']}"}

    sessions_response = test_client.get("/auth/sessions", headers=headers)
    assert sessions_response.status_code == 200, sessions_response.text
    assert len(sessions_response.json()) == 1

    refresh_response = test_client.post("/auth/refresh", json={"refresh_token": login_payload["refresh_token"]})
    assert refresh_response.status_code == 200, refresh_response.text
    refresh_payload = refresh_response.json()
    refreshed_headers = {"Authorization": f"Bearer {refresh_payload['access_token']}"}

    logout_response = test_client.post("/auth/logout", headers=refreshed_headers)
    assert logout_response.status_code == 200, logout_response.text

    me_response = test_client.get("/auth/me", headers=refreshed_headers)
    assert me_response.status_code == 401


def test_account_is_temporarily_locked_after_repeated_failed_logins(client):
    test_client, session_local = client
    seed_base_data(session_local)

    for _ in range(5):
        response = test_client.post("/auth/login", json={"username": "operator", "password": "wrong-password"})
        assert response.status_code == 401

    locked_response = test_client.post("/auth/login", json={"username": "operator", "password": "operator123"})
    assert locked_response.status_code == 423

    db = session_local()
    try:
        operator = db.query(User).filter(User.username == "operator").first()
        assert operator.locked_until is not None
    finally:
        db.close()
