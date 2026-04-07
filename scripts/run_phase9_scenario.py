"""Run a repeatable Phase 9 operations scenario through the live backend API.

Run from the repository root while the backend is running:
    venv\\Scripts\\python.exe scripts\\run_phase9_scenario.py
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from ensure_phase9_tenant import main as ensure_phase9_tenant  # noqa: E402


BASE_URL = os.environ.get("PPMS_API_BASE_URL", "http://127.0.0.1:8012").rstrip("/")
SCENARIO_PASSWORD = "operator123"


class ApiClient:
    def __init__(self, base_url: str, token: str | None = None) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token

    def request(
        self,
        method: str,
        path: str,
        *,
        payload: dict[str, Any] | None = None,
        query: dict[str, Any] | None = None,
    ) -> Any:
        url = f"{self.base_url}{path}"
        if query:
            clean_query = {
                key: value
                for key, value in query.items()
                if value is not None
            }
            url = f"{url}?{urllib.parse.urlencode(clean_query)}"

        body = None
        headers = {"Accept": "application/json"}
        if payload is not None:
            body = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        request = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                content = response.read().decode("utf-8")
                if not content:
                    return None
                return json.loads(content)
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {path} failed with {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(
                f"Cannot reach backend at {self.base_url}. Start it with .\\restart_local_dev.ps1 first."
            ) from exc

    def get(self, path: str, *, query: dict[str, Any] | None = None) -> Any:
        return self.request("GET", path, query=query)

    def post(self, path: str, payload: dict[str, Any] | None = None) -> Any:
        return self.request("POST", path, payload=payload or {})

    def login(self, username: str, password: str) -> "ApiClient":
        response = self.post("/auth/login", {"username": username, "password": password})
        token = response["access_token"]
        return ApiClient(self.base_url, token)


def approx_equal(left: float | None, right: float | None, tolerance: float = 0.01) -> bool:
    if left is None or right is None:
        return False
    return abs(float(left) - float(right)) <= tolerance


def first_nozzle(setup: dict[str, Any]) -> dict[str, Any]:
    for dispenser in setup["dispensers"]:
        nozzles = dispenser.get("nozzles") or []
        if nozzles:
            return nozzles[0]
    raise RuntimeError("No nozzle exists in the Phase 9 test station")


def role_id(roles: list[dict[str, Any]], name: str) -> int:
    for role in roles:
        if role["name"] == name:
            return int(role["id"])
    raise RuntimeError(f"Role not found: {name}")


def main() -> int:
    print("Preparing Phase 9 tenant...")
    ensure_phase9_tenant()

    anonymous = ApiClient(BASE_URL)
    anonymous.get("/health")
    head_office = anonymous.login("check", "office123")
    manager = anonymous.login("check_manager", "manager123")

    timestamp = int(time.time())
    scenario_id = f"P9-{timestamp}"
    scenario_username = f"p9_operator_{timestamp}"
    print(f"Running scenario {scenario_id}...")

    stations = head_office.get("/stations/", query={"organization_id": 4})
    if len(stations) != 1:
        raise RuntimeError(f"Expected one Phase 9 station, found {len(stations)}")
    station = stations[0]
    station_id = int(station["id"])
    organization_id = int(station["organization_id"])

    roles = head_office.get("/roles/")
    operator_role_id = role_id(roles, "Operator")
    scenario_user = head_office.post(
        "/users/",
        {
            "full_name": f"{scenario_id} Operator",
            "username": scenario_username,
            "email": f"{scenario_username}@example.com",
            "password": SCENARIO_PASSWORD,
            "role_id": operator_role_id,
            "organization_id": organization_id,
            "station_id": station_id,
            "scope_level": "station",
            "monthly_salary": 0,
            "payroll_enabled": True,
        },
    )
    operator = anonymous.login(scenario_username, SCENARIO_PASSWORD)

    setup_before = operator.get(f"/stations/{station_id}/setup-foundation")
    nozzle = first_nozzle(setup_before)
    tank_before = next(
        item for item in setup_before["tanks"] if int(item["id"]) == int(nozzle["tank_id"])
    )

    opening_cash = 500.0
    sale_liters = 5.0
    sale_rate = 250.0
    sale_total = sale_liters * sale_rate
    cash_expected = opening_cash + sale_total
    purchase_quantity = 50.0
    purchase_rate = 240.0
    purchase_total = purchase_quantity * purchase_rate
    expense_amount = 123.0

    shift = operator.post(
        "/shifts/",
        {
            "station_id": station_id,
            "initial_cash": opening_cash,
            "notes": f"{scenario_id} operator opening cash",
        },
    )
    sale = operator.post(
        "/fuel-sales/",
        {
            "nozzle_id": nozzle["id"],
            "station_id": station_id,
            "fuel_type_id": nozzle["fuel_type_id"],
            "closing_meter": float(nozzle["meter_reading"]) + sale_liters,
            "rate_per_liter": sale_rate,
            "sale_type": "cash",
            "shift_id": shift["id"],
        },
    )
    cash_submission = operator.post(
        f"/shifts/{shift['id']}/cash-submissions",
        {
            "amount": sale_total,
            "notes": f"{scenario_id} cash submission",
        },
    )
    closed_shift = operator.post(
        f"/shifts/{shift['id']}/close",
        {
            "actual_cash_collected": cash_expected,
            "notes": f"{scenario_id} balanced close",
        },
    )
    shift_cash = manager.get(f"/shifts/{shift['id']}/cash")

    expense = manager.post(
        "/expenses/",
        {
            "station_id": station_id,
            "title": f"{scenario_id} manager test expense",
            "category": "phase9",
            "amount": expense_amount,
            "notes": "Created by the Phase 9 scenario runner",
        },
    )
    supplier = manager.post(
        "/suppliers/",
        {
            "name": f"{scenario_id} Test Supplier",
            "code": scenario_id,
            "phone": "000-000",
            "address": "Phase 9 scenario",
        },
    )
    purchase = manager.post(
        "/purchases/",
        {
            "supplier_id": supplier["id"],
            "tank_id": tank_before["id"],
            "fuel_type_id": tank_before["fuel_type_id"],
            "quantity": purchase_quantity,
            "rate_per_liter": purchase_rate,
            "reference_no": scenario_id,
            "notes": "Created by the Phase 9 scenario runner",
        },
    )

    setup_after_purchase = manager.get(f"/stations/{station_id}/setup-foundation")
    tank_after_purchase = next(
        item
        for item in setup_after_purchase["tanks"]
        if int(item["id"]) == int(tank_before["id"])
    )
    dip_volume = float(tank_after_purchase["current_volume"])
    tank_dip = manager.post(
        "/tank-dips/",
        {
            "tank_id": tank_before["id"],
            "dip_reading_mm": 100.0,
            "calculated_volume": dip_volume,
            "notes": f"{scenario_id} dip matches system stock",
        },
    )

    expected_tank_volume = float(tank_before["current_volume"]) - sale_liters
    if purchase["status"] == "approved":
        expected_tank_volume += purchase_quantity

    checks = [
        {
            "name": "fuel sale quantity is meter-derived",
            "passed": approx_equal(sale["quantity"], sale_liters),
            "expected": sale_liters,
            "actual": sale["quantity"],
        },
        {
            "name": "fuel sale total is quantity times rate",
            "passed": approx_equal(sale["total_amount"], sale_total),
            "expected": sale_total,
            "actual": sale["total_amount"],
        },
        {
            "name": "sale is attached to operator shift",
            "passed": sale["shift_id"] == shift["id"],
            "expected": shift["id"],
            "actual": sale["shift_id"],
        },
        {
            "name": "cash submission records the sale cash",
            "passed": approx_equal(cash_submission["amount"], sale_total),
            "expected": sale_total,
            "actual": cash_submission["amount"],
        },
        {
            "name": "closed shift expected cash includes opening cash and cash sales",
            "passed": approx_equal(closed_shift["expected_cash"], cash_expected),
            "expected": cash_expected,
            "actual": closed_shift["expected_cash"],
        },
        {
            "name": "closed shift balances with zero difference",
            "passed": approx_equal(closed_shift["difference"], 0.0),
            "expected": 0.0,
            "actual": closed_shift["difference"],
        },
        {
            "name": "manager can review shift cash",
            "passed": approx_equal(shift_cash["cash_submitted"], sale_total),
            "expected": sale_total,
            "actual": shift_cash["cash_submitted"],
        },
        {
            "name": "expense records manager amount",
            "passed": approx_equal(expense["amount"], expense_amount),
            "expected": expense_amount,
            "actual": expense["amount"],
        },
        {
            "name": "purchase total is quantity times rate",
            "passed": approx_equal(purchase["total_amount"], purchase_total),
            "expected": purchase_total,
            "actual": purchase["total_amount"],
        },
        {
            "name": "tank stock matches approved/pending purchase behavior",
            "passed": approx_equal(tank_after_purchase["current_volume"], expected_tank_volume),
            "expected": expected_tank_volume,
            "actual": tank_after_purchase["current_volume"],
        },
        {
            "name": "dip matches current system stock",
            "passed": approx_equal(tank_dip["loss_gain"], 0.0),
            "expected": 0.0,
            "actual": tank_dip["loss_gain"],
        },
    ]

    summary = {
        "scenario_id": scenario_id,
        "base_url": BASE_URL,
        "tenant": {
            "organization_id": organization_id,
            "station_id": station_id,
            "station": station["name"],
            "station_code": station["code"],
        },
        "created": {
            "operator_user_id": scenario_user["id"],
            "operator_username": scenario_username,
            "shift_id": shift["id"],
            "fuel_sale_id": sale["id"],
            "cash_submission_id": cash_submission["id"],
            "expense_id": expense["id"],
            "supplier_id": supplier["id"],
            "purchase_id": purchase["id"],
            "tank_dip_id": tank_dip["id"],
        },
        "expected": {
            "sale_liters": sale_liters,
            "sale_total": sale_total,
            "cash_expected": cash_expected,
            "purchase_status": purchase["status"],
            "purchase_total": purchase_total,
            "tank_volume_after_sale_and_purchase_rule": expected_tank_volume,
        },
        "actual": {
            "sale_quantity": sale["quantity"],
            "sale_total": sale["total_amount"],
            "closed_shift_expected_cash": closed_shift["expected_cash"],
            "closed_shift_difference": closed_shift["difference"],
            "cash_submitted": shift_cash["cash_submitted"],
            "purchase_status": purchase["status"],
            "purchase_total": purchase["total_amount"],
            "tank_volume_before": tank_before["current_volume"],
            "tank_volume_after": tank_after_purchase["current_volume"],
            "dip_loss_gain": tank_dip["loss_gain"],
        },
        "checks": checks,
        "passed": all(item["passed"] for item in checks),
    }

    print(json.dumps(summary, indent=2))
    if not summary["passed"]:
        print("Phase 9 scenario failed.")
        return 1
    print("Phase 9 scenario passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
