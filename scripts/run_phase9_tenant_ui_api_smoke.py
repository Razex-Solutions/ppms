"""Smoke-test API calls used by the clean tenant Flutter workspaces.

Run from the repository root while the backend is running:
    venv\\Scripts\\python.exe scripts\\run_phase9_tenant_ui_api_smoke.py
"""

from __future__ import annotations

import datetime as dt
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from ensure_phase9_tenant import main as ensure_phase9_tenant  # noqa: E402
from run_phase9_scenario import ApiClient, BASE_URL  # noqa: E402


TEST_LOGINS = {
    "check_head_office": ("check", "office123"),
    "check_accountant": ("check_accountant", "accountant123"),
    "check_manager": ("check_manager", "manager123"),
    "check_operator": ("check_operator", "operator123"),
    "multi_station_admin_a": ("p9_multi_station_a_admin", "station123"),
    "multi_station_admin_b": ("p9_multi_station_b_admin", "station123"),
    "minimal_head_office": ("p9_minimal", "office123"),
}


OPTIONAL_WORKSPACES = {
    "tankers": "tanker_operations",
    "pos": "pos",
    "pos_sale": "pos",
    "hardware": "hardware",
}


def _station_query(station_id: int | None) -> str:
    return "" if station_id is None else f"?station_id={station_id}"


def _today_report_query(station_id: int | None) -> str:
    today = dt.date.today().isoformat()
    if station_id is None:
        return f"?report_date={today}"
    return f"?report_date={today}&station_id={station_id}"


def _workspace_paths(
    role_name: str,
    workspace_id: str,
    organization_id: int | None,
    station_id: int | None,
) -> list[str]:
    station_query = _station_query(station_id)
    if workspace_id == "users":
        if role_name == "HeadOffice" and organization_id is not None:
            return [f"/users/?organization_id={organization_id}"]
        if station_id is not None:
            return [f"/users/?station_id={station_id}"]
        return ["/users/"]
    if workspace_id == "tenant_setup":
        return [] if organization_id is None else [f"/organizations/{organization_id}/setup-foundation"]
    if workspace_id in {"station_setup", "inventory_dips"}:
        return [] if station_id is None else [f"/stations/{station_id}/setup-foundation"]
    if workspace_id in {"shifts", "shift", "cash"}:
        return [f"/shifts/{station_query}"]
    if workspace_id in {"fuel_sales", "fuel_sale", "sales_review"}:
        return [f"/fuel-sales/{station_query}"]
    if workspace_id == "purchases":
        return [f"/purchases/{station_query}"]
    if workspace_id == "expenses":
        return [f"/expenses/{station_query}"]
    if workspace_id in {"finance", "finance_overview"}:
        return [
            f"/purchases/{station_query}",
            f"/expenses/{station_query}",
            f"/customer-payments/{station_query}",
            f"/supplier-payments/{station_query}",
        ]
    if workspace_id == "parties":
        return ["/customers/", "/suppliers/"]
    if workspace_id == "payments":
        return [f"/customer-payments/{station_query}", f"/supplier-payments/{station_query}"]
    if workspace_id == "payroll":
        return [f"/payroll/runs{station_query}"]
    if workspace_id == "attendance":
        return [f"/attendance/{station_query}"]
    if workspace_id == "tankers":
        return [f"/tankers/{station_query}", f"/tankers/trips{station_query}"]
    if workspace_id in {"pos", "pos_sale"}:
        return [f"/pos-products/{station_query}", f"/pos-sales/{station_query}"]
    if workspace_id == "reports":
        return [
            f"/reports/daily-closing{_today_report_query(station_id)}",
            "/report-definitions/",
            "/report-exports/",
        ]
    if workspace_id == "documents":
        paths = ["/financial-documents/dispatches"]
        if station_id is not None:
            paths.insert(0, f"/document-templates/{station_id}")
        return paths
    if workspace_id == "notifications":
        return [
            "/notifications/summary",
            "/notifications/",
            "/notifications/deliveries",
            "/notifications/preferences",
        ]
    return []


def _workspaces_for(role_name: str) -> list[str]:
    if role_name == "HeadOffice":
        return [
            "tenant_setup",
            "users",
            "station_setup",
            "inventory_dips",
            "finance_overview",
            "tankers",
            "pos",
            "hardware",
            "reports",
            "documents",
            "notifications",
        ]
    if role_name == "StationAdmin":
        return [
            "users",
            "station_setup",
            "inventory_dips",
            "shifts",
            "fuel_sales",
            "cash",
            "purchases",
            "expenses",
            "tankers",
            "pos",
            "attendance",
            "reports",
        ]
    if role_name == "Manager":
        return [
            "shifts",
            "fuel_sales",
            "sales_review",
            "cash",
            "purchases",
            "expenses",
            "inventory_dips",
            "tankers",
            "pos",
            "attendance",
            "reports",
        ]
    if role_name == "Accountant":
        return [
            "finance",
            "purchases",
            "expenses",
            "parties",
            "payments",
            "payroll",
            "attendance",
            "tankers",
            "documents",
            "reports",
            "notifications",
        ]
    if role_name == "Operator":
        return ["shift", "fuel_sale", "cash", "inventory_dips", "pos_sale"]
    return []


def _features(me: dict[str, Any]) -> dict[str, bool]:
    flags = me.get("feature_flags")
    if isinstance(flags, dict):
        return {str(key): bool(value) for key, value in flags.items()}
    modules = me.get("effective_enabled_modules")
    if isinstance(modules, list):
        return {str(name): True for name in modules}
    return {}


def _visible_workspaces(role_name: str, me: dict[str, Any]) -> list[str]:
    flags = _features(me)
    visible = []
    for workspace in _workspaces_for(role_name):
        required = OPTIONAL_WORKSPACES.get(workspace)
        if required is not None and not flags.get(required, False):
            continue
        visible.append(workspace)
    return visible


def _working_station_id(client: ApiClient, me: dict[str, Any]) -> int | None:
    station_id = me.get("station_id")
    if station_id is not None:
        return int(station_id)
    organization_id = me.get("organization_id")
    stations = client.get("/stations/", query={"organization_id": organization_id})
    if isinstance(stations, list) and len(stations) == 1:
        return int(stations[0]["id"])
    return None


def main() -> None:
    ensure_phase9_tenant()
    root = ApiClient(BASE_URL)
    failures: list[str] = []
    checks = 0
    for label, (username, password) in TEST_LOGINS.items():
        client = root.login(username, password)
        me = client.get("/auth/me")
        role_name = str(me["role_name"])
        organization_id = me.get("organization_id")
        station_id = _working_station_id(client, me)
        for workspace in _visible_workspaces(role_name, me):
            for path in _workspace_paths(role_name, workspace, organization_id, station_id):
                checks += 1
                try:
                    client.get(path)
                except Exception as exc:  # noqa: BLE001 - smoke output should capture exact failure.
                    failures.append(f"{label} {role_name} {workspace} GET {path}: {exc}")
    if failures:
        print("Phase 9 tenant Flutter API smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        raise SystemExit(1)
    print(f"Phase 9 tenant Flutter API smoke passed ({checks} endpoint checks).")


if __name__ == "__main__":
    main()
