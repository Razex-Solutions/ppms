from tests.conftest import login, seed_base_data


def test_attendance_check_in_out_and_manual_record_flow(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    operator_headers = login(test_client, "operator", "operator123")
    manager_headers = login(test_client, "manager", "manager123")

    check_in_response = test_client.post(
        "/attendance/check-in",
        headers=operator_headers,
        json={"station_id": data["station_a_id"], "notes": "Started morning shift"},
    )
    assert check_in_response.status_code == 200, check_in_response.text
    attendance_id = check_in_response.json()["id"]
    assert check_in_response.json()["status"] == "present"
    assert check_in_response.json()["check_in_at"] is not None

    duplicate_check_in = test_client.post(
        "/attendance/check-in",
        headers=operator_headers,
        json={"station_id": data["station_a_id"]},
    )
    assert duplicate_check_in.status_code == 400

    check_out_response = test_client.post(
        f"/attendance/{attendance_id}/check-out",
        headers=operator_headers,
        json={"notes": "Closed shift"},
    )
    assert check_out_response.status_code == 200, check_out_response.text
    assert check_out_response.json()["check_out_at"] is not None

    db = session_local()
    try:
        from app.models.user import User

        manager = db.query(User).filter(User.username == "manager").first()
        manager_id = manager.id
    finally:
        db.close()

    manual_record = test_client.post(
        "/attendance/",
        headers=manager_headers,
        json={
            "user_id": manager_id,
            "station_id": data["station_a_id"],
            "attendance_date": "2026-04-01",
            "status": "leave",
            "notes": "Approved leave",
        },
    )
    assert manual_record.status_code == 200, manual_record.text
    assert manual_record.json()["status"] == "leave"

    attendance_list = test_client.get("/attendance/", headers=manager_headers)
    assert attendance_list.status_code == 200, attendance_list.text
    assert len(attendance_list.json()) >= 2


def test_payroll_run_generation_and_finalize(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    manager_headers = login(test_client, "manager", "manager123")
    accountant_headers = login(test_client, "accountant", "accountant123")
    head_office_headers = login(test_client, "headoffice", "headoffice123")

    db = session_local()
    try:
        from app.models.user import User

        operator = db.query(User).filter(User.username == "operator").first()
        accountant = db.query(User).filter(User.username == "accountant").first()
        operator.monthly_salary = 3000
        accountant.monthly_salary = 6000
        db.commit()
        operator_id = operator.id
        accountant_id = accountant.id
    finally:
        db.close()

    for user_id, status in [(operator_id, "present"), (accountant_id, "half_day")]:
        response = test_client.post(
            "/attendance/",
            headers=manager_headers,
            json={
                "user_id": user_id,
                "station_id": data["station_a_id"],
                "attendance_date": "2026-04-01",
                "status": status,
            },
        )
        assert response.status_code == 200, response.text

    payroll_run = test_client.post(
        "/payroll/runs",
        headers=accountant_headers,
        json={
            "station_id": data["station_a_id"],
            "period_start": "2026-04-01",
            "period_end": "2026-04-01",
            "notes": "April daily payroll",
        },
    )
    assert payroll_run.status_code == 200, payroll_run.text
    payroll_run_id = payroll_run.json()["id"]
    assert payroll_run.json()["status"] == "draft"
    assert payroll_run.json()["total_staff"] >= 2

    payroll_lines = test_client.get(f"/payroll/runs/{payroll_run_id}/lines", headers=accountant_headers)
    assert payroll_lines.status_code == 200, payroll_lines.text
    line_by_user = {line["user_id"]: line for line in payroll_lines.json()}
    assert line_by_user[operator_id]["gross_amount"] == 100.0
    assert line_by_user[accountant_id]["gross_amount"] == 100.0

    finalize_response = test_client.post(
        f"/payroll/runs/{payroll_run_id}/finalize",
        headers=head_office_headers,
        json={"notes": "Approved payroll"},
    )
    assert finalize_response.status_code == 200, finalize_response.text
    assert finalize_response.json()["status"] == "finalized"
    assert finalize_response.json()["finalized_by_user_id"] is not None


def test_payroll_and_attendance_are_station_scoped(client):
    test_client, session_local = client
    data = seed_base_data(session_local)
    foreign_manager_headers = login(test_client, "foreignmanager", "foreign123")
    manager_headers = login(test_client, "manager", "manager123")

    db = session_local()
    try:
        from app.models.user import User

        operator = db.query(User).filter(User.username == "operator").first()
        operator_id = operator.id
    finally:
        db.close()

    forbidden_attendance = test_client.post(
        "/attendance/",
        headers=foreign_manager_headers,
        json={
            "user_id": operator_id,
            "station_id": data["station_a_id"],
            "attendance_date": "2026-04-01",
            "status": "present",
        },
    )
    assert forbidden_attendance.status_code == 403

    forbidden_payroll = test_client.post(
        "/payroll/runs",
        headers=foreign_manager_headers,
        json={
            "station_id": data["station_a_id"],
            "period_start": "2026-04-01",
            "period_end": "2026-04-01",
        },
    )
    assert forbidden_payroll.status_code == 403

    allowed_attendance = test_client.get("/attendance/", headers=manager_headers)
    assert allowed_attendance.status_code == 200
