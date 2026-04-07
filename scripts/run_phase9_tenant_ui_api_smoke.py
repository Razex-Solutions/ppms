"""Matrix-driven smoke-test for clean tenant Flutter API contracts.

Run from the repository root while the backend is running:
    venv\\Scripts\\python.exe scripts\\run_phase9_tenant_ui_api_smoke.py

The source of truth is scripts/tenant_role_matrix.json. This smoke test
executes safe read APIs for the visible screens of representative Phase 9
logins. Mutating create/update/delete APIs are validated by the full Phase 9
scenario runner so this script can stay idempotent.
"""

from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MATRIX_PATH = ROOT / "scripts" / "tenant_role_matrix.json"
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

ACTION_KEYS = ("create_apis", "update_apis", "delete_apis", "approval_apis")


def load_matrix() -> dict[str, Any]:
    return json.loads(MATRIX_PATH.read_text(encoding="utf-8"))


def features(me: dict[str, Any]) -> dict[str, bool]:
    flags = me.get("feature_flags")
    if isinstance(flags, dict):
        return {str(key): bool(value) for key, value in flags.items()}
    modules = me.get("effective_enabled_modules")
    if isinstance(modules, list):
        return {str(name): True for name in modules}
    return {}


def screen_is_visible(screen: dict[str, Any], enabled_features: dict[str, bool]) -> bool:
    if screen.get("visible") is True:
        return True
    required_modules = screen.get("visible_when_modules")
    if isinstance(required_modules, list):
        return any(enabled_features.get(str(module_name), False) for module_name in required_modules)
    return False


def working_station_id(client: ApiClient, me: dict[str, Any]) -> int | None:
    station_id = me.get("station_id")
    if station_id is not None:
        return int(station_id)
    organization_id = me.get("organization_id")
    stations = client.get("/stations/", query={"organization_id": organization_id})
    if isinstance(stations, list) and len(stations) == 1:
        return int(stations[0]["id"])
    return None


def first_id(rows: Any) -> int | None:
    if not isinstance(rows, list) or not rows:
        return None
    first = rows[0]
    if isinstance(first, dict) and first.get("id") is not None:
        return int(first["id"])
    return None


def build_placeholders(client: ApiClient, me: dict[str, Any], station_id: int | None) -> dict[str, Any]:
    organization_id = me.get("organization_id")
    placeholders: dict[str, Any] = {
        "organization_id": organization_id,
        "station_id": station_id,
        "today": dt.date.today().isoformat(),
        "user_id": me.get("id"),
    }

    optional_sources = {
        "customer_id": "/customers/",
        "supplier_id": "/suppliers/",
        "payroll_run_id": f"/payroll/runs?station_id={station_id}" if station_id is not None else "/payroll/runs",
        "shift_id": f"/shifts/?station_id={station_id}" if station_id is not None else "/shifts/",
        "attendance_id": f"/attendance/?station_id={station_id}" if station_id is not None else "/attendance/",
    }
    for key, path in optional_sources.items():
        try:
            placeholders[key] = first_id(client.get(path))
        except Exception:  # noqa: BLE001 - missing optional IDs should not fail unrelated screens.
            placeholders[key] = None
    return placeholders


def render_api_path(template: str, placeholders: dict[str, Any]) -> str | None:
    parts = template.split(" ", 1)
    if len(parts) != 2:
        raise ValueError(f"API entry must include method and path: {template}")
    method, path = parts[0].upper(), parts[1]
    if method != "GET":
        return None
    for key, value in placeholders.items():
        token = "{" + key + "}"
        if token in path:
            if value is None:
                return None
            path = path.replace(token, str(value))
    if "{" in path or "}" in path:
        return None
    return path


def matrix_read_paths_for(
    *,
    role_name: str,
    enabled_features: dict[str, bool],
    matrix: dict[str, Any],
    placeholders: dict[str, Any],
) -> tuple[list[tuple[str, str]], list[str]]:
    roles = matrix.get("roles")
    if not isinstance(roles, dict) or role_name not in roles:
        raise RuntimeError(f"Role {role_name} is missing from {MATRIX_PATH}")
    role_entry = roles[role_name]
    screens = role_entry.get("screens")
    if not isinstance(screens, dict):
        raise RuntimeError(f"Role {role_name} has no screens object in {MATRIX_PATH}")

    read_paths: list[tuple[str, str]] = []
    declared_actions: list[str] = []
    for screen_name, screen_value in screens.items():
        if not isinstance(screen_value, dict):
            raise RuntimeError(f"{role_name}.{screen_name} must be an object")
        if not screen_is_visible(screen_value, enabled_features):
            continue
        for action_key in ACTION_KEYS:
            for entry in screen_value.get(action_key, []):
                declared_actions.append(f"{role_name}.{screen_name}.{action_key}: {entry}")
        for api_entry in screen_value.get("read_apis", []):
            path = render_api_path(str(api_entry), placeholders)
            if path is not None:
                read_paths.append((screen_name, path))
    return read_paths, declared_actions


def main() -> None:
    ensure_phase9_tenant()
    matrix = load_matrix()
    root = ApiClient(BASE_URL)
    failures: list[str] = []
    checks = 0
    skipped_placeholder_reads = 0
    declared_actions = 0

    for label, (username, password) in TEST_LOGINS.items():
        client = root.login(username, password)
        me = client.get("/auth/me")
        role_name = str(me["role_name"])
        station_id = working_station_id(client, me)
        placeholders = build_placeholders(client, me, station_id)
        read_paths, action_contracts = matrix_read_paths_for(
            role_name=role_name,
            enabled_features=features(me),
            matrix=matrix,
            placeholders=placeholders,
        )
        declared_actions += len(action_contracts)
        for screen_name, path in read_paths:
            checks += 1
            try:
                client.get(path)
            except Exception as exc:  # noqa: BLE001 - smoke output should capture exact failure.
                failures.append(f"{label} {role_name} {screen_name} GET {path}: {exc}")

        role_screens = matrix["roles"][role_name]["screens"]
        for screen_value in role_screens.values():
            if not isinstance(screen_value, dict) or not screen_is_visible(screen_value, features(me)):
                continue
            for api_entry in screen_value.get("read_apis", []):
                if render_api_path(str(api_entry), placeholders) is None:
                    skipped_placeholder_reads += 1

    if failures:
        print("Phase 9 tenant Flutter API smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        raise SystemExit(1)

    print(
        "Phase 9 tenant Flutter API smoke passed "
        f"({checks} matrix read endpoint checks, "
        f"{declared_actions} mutating contracts delegated to scenario runner, "
        f"{skipped_placeholder_reads} read templates skipped for missing optional IDs)."
    )


if __name__ == "__main__":
    main()
