"""Run repeatable Phase 9 sample data through the live backend API.

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
MANIFEST_PATH = ROOT / "scripts" / "phase9_dataset_manifest.json"


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
        return ApiClient(self.base_url, response["access_token"])


def approx_equal(left: float | None, right: float | None, tolerance: float = 0.01) -> bool:
    if left is None or right is None:
        return False
    return abs(float(left) - float(right)) <= tolerance


def check(name: str, actual: Any, expected: Any, *, approximate: bool = False) -> dict[str, Any]:
    passed = approx_equal(actual, expected) if approximate else actual == expected
    return {
        "name": name,
        "passed": passed,
        "expected": expected,
        "actual": actual,
    }


def load_manifest() -> dict[str, Any]:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def role_id(roles: list[dict[str, Any]], name: str) -> int:
    for role in roles:
        if role["name"] == name:
            return int(role["id"])
    raise RuntimeError(f"Role not found: {name}")


def flatten_nozzles(setup: dict[str, Any]) -> list[dict[str, Any]]:
    nozzles: list[dict[str, Any]] = []
    for dispenser in setup["dispensers"]:
        nozzles.extend(dispenser.get("nozzles") or [])
    if not nozzles:
        raise RuntimeError("No nozzles exist in the Phase 9 test station")
    return nozzles


def create_login_user(
    *,
    head_office: ApiClient,
    role_ids: dict[str, int],
    scenario_id: str,
    user_spec: dict[str, Any],
    organization_id: int,
    station_id: int,
) -> dict[str, Any]:
    username = f"{user_spec['username_prefix']}_{scenario_id.lower().replace('-', '_')}"
    role_name = user_spec["role"]
    return head_office.post(
        "/users/",
        {
            "full_name": f"{scenario_id} {role_name} {user_spec['username_prefix']}",
            "username": username,
            "email": f"{username}@example.com",
            "password": user_spec["password"],
            "role_id": role_ids[role_name],
            "organization_id": organization_id,
            "station_id": station_id,
            "scope_level": "station",
            "monthly_salary": 0,
            "payroll_enabled": True,
        },
    )


def create_employee_profile(
    *,
    client: ApiClient,
    scenario_id: str,
    station_id: int,
    profile_spec: dict[str, Any],
    index: int,
) -> dict[str, Any]:
    return client.post(
        "/employee-profiles/",
        {
            "station_id": station_id,
            "full_name": profile_spec["name"],
            "staff_type": profile_spec["profile_type"],
            "employee_code": f"{scenario_id}-EMP-{index:02d}",
            "phone": f"0300-000-{index:04d}",
            "national_id": f"{scenario_id}-{index:04d}",
            "address": "Phase 9 sample staff",
            "is_active": True,
            "payroll_enabled": True,
            "monthly_salary": profile_spec["monthly_salary"],
            "can_login": profile_spec["login_allowed"],
            "notes": f"{scenario_id} generated staff profile",
        },
    )


def run_shift_scenario(
    *,
    anonymous: ApiClient,
    scenario_id: str,
    scenario_spec: dict[str, Any],
    operator_user: dict[str, Any],
    nozzles: list[dict[str, Any]],
    station_id: int,
) -> dict[str, Any]:
    operator = anonymous.login(operator_user["username"], operator_user["password"])
    shift = operator.post(
        "/shifts/",
        {
            "station_id": station_id,
            "initial_cash": scenario_spec["opening_cash"],
            "notes": f"{scenario_id} {scenario_spec['name']} opening cash",
        },
    )

    sales: list[dict[str, Any]] = []
    for sale_spec in scenario_spec["sales"]:
        nozzle = nozzles[int(sale_spec["nozzle_sequence"]) - 1]
        current_setup = operator.get(f"/stations/{station_id}/setup-foundation")
        current_nozzles = flatten_nozzles(current_setup)
        current_nozzle = next(
            item for item in current_nozzles if int(item["id"]) == int(nozzle["id"])
        )
        sale = operator.post(
            "/fuel-sales/",
            {
                "nozzle_id": current_nozzle["id"],
                "station_id": station_id,
                "fuel_type_id": current_nozzle["fuel_type_id"],
                "closing_meter": float(current_nozzle["meter_reading"]) + float(sale_spec["liters"]),
                "rate_per_liter": sale_spec["rate"],
                "sale_type": "cash",
                "shift_id": shift["id"],
            },
        )
        sales.append(sale)

    cash_submissions: list[dict[str, Any]] = []
    for amount in scenario_spec.get("cash_submissions", []):
        cash_submissions.append(
            operator.post(
                f"/shifts/{shift['id']}/cash-submissions",
                {
                    "amount": amount,
                    "notes": f"{scenario_id} {scenario_spec['name']} cash submission",
                },
            )
        )

    closed_shift = None
    if not scenario_spec.get("leave_open", False):
        closed_shift = operator.post(
            f"/shifts/{shift['id']}/close",
            {
                "actual_cash_collected": scenario_spec["actual_cash_collected"],
                "notes": f"{scenario_id} {scenario_spec['name']} close",
            },
        )

    return {
        "scenario": scenario_spec["name"],
        "operator_username": operator_user["username"],
        "shift": shift,
        "closed_shift": closed_shift,
        "sales": sales,
        "cash_submissions": cash_submissions,
    }


def create_expenses(
    *,
    manager: ApiClient,
    scenario_id: str,
    station_id: int,
    expense_specs: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    return [
        manager.post(
            "/expenses/",
            {
                "station_id": station_id,
                "title": f"{scenario_id} {item['category']} expense",
                "category": item["category"],
                "amount": item["amount"],
                "notes": "Created by the Phase 9 scenario runner",
            },
        )
        for item in expense_specs
    ]


def create_purchases(
    *,
    manager: ApiClient,
    scenario_id: str,
    tanks: list[dict[str, Any]],
    purchase_specs: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    purchases: list[dict[str, Any]] = []
    for index, purchase_spec in enumerate(purchase_specs, start=1):
        supplier = manager.post(
            "/suppliers/",
            {
                "name": f"{scenario_id} Fuel Supplier {index}",
                "code": f"{scenario_id}-SUP-{index}",
                "phone": "000-000",
                "address": "Phase 9 scenario",
            },
        )
        tank = tanks[(index - 1) % len(tanks)]
        purchases.append(
            manager.post(
                "/purchases/",
                {
                    "supplier_id": supplier["id"],
                    "tank_id": tank["id"],
                    "fuel_type_id": tank["fuel_type_id"],
                    "quantity": purchase_spec["quantity"],
                    "rate_per_liter": purchase_spec["rate_per_liter"],
                    "reference_no": f"{scenario_id}-PUR-{index}",
                    "notes": "Created by the Phase 9 scenario runner",
                },
            )
        )
    return purchases


def approve_purchases_and_pay_suppliers(
    *,
    head_office: ApiClient,
    accountant: ApiClient,
    scenario_id: str,
    station_id: int,
    purchases: list[dict[str, Any]],
    supplier_specs: list[dict[str, Any]],
) -> dict[str, Any]:
    approved_purchases: list[dict[str, Any]] = []
    supplier_payments: list[dict[str, Any]] = []
    supplier_ledgers: list[dict[str, Any]] = []
    suppliers_after_payment: list[dict[str, Any]] = []

    for purchase, supplier_spec in zip(purchases, supplier_specs):
        approved_purchase = head_office.post(
            f"/purchases/{purchase['id']}/approve",
            {"reason": f"{scenario_id} Phase 9 supplier payable check"},
        )
        approved_purchases.append(approved_purchase)
        supplier_payment = accountant.post(
            "/supplier-payments/",
            {
                "supplier_id": approved_purchase["supplier_id"],
                "station_id": station_id,
                "amount": supplier_spec["payment_amount"],
                "payment_method": "cash",
                "reference_no": f"{scenario_id}-SPAY-{approved_purchase['id']}",
                "notes": "Created by the Phase 9 scenario runner",
            },
        )
        supplier_payments.append(supplier_payment)
        supplier_ledgers.append(
            accountant.get(
                f"/ledger/supplier/{approved_purchase['supplier_id']}",
                query={"station_id": station_id},
            )
        )
        suppliers_after_payment.append(accountant.get(f"/suppliers/{approved_purchase['supplier_id']}"))

    return {
        "approved_purchases": approved_purchases,
        "supplier_payments": supplier_payments,
        "supplier_ledgers": supplier_ledgers,
        "suppliers_after_payment": suppliers_after_payment,
    }


def create_credit_customer_flow(
    *,
    anonymous: ApiClient,
    accountant: ApiClient,
    scenario_id: str,
    operator_user: dict[str, Any],
    station_id: int,
    customer_specs: list[dict[str, Any]],
    nozzles: list[dict[str, Any]],
) -> dict[str, Any]:
    operator = anonymous.login(operator_user["username"], operator_user["password"])
    shift = operator.post(
        "/shifts/",
        {
            "station_id": station_id,
            "initial_cash": 0,
            "notes": f"{scenario_id} credit customer shift",
        },
    )

    customers: list[dict[str, Any]] = []
    credit_sales: list[dict[str, Any]] = []
    customer_payments: list[dict[str, Any]] = []
    customer_ledgers: list[dict[str, Any]] = []
    customers_after_payment: list[dict[str, Any]] = []

    for index, customer_spec in enumerate(customer_specs, start=1):
        customer = accountant.post(
            "/customers/",
            {
                "name": f"{scenario_id} {customer_spec['name']}",
                "code": f"{scenario_id}-CUST-{index}",
                "customer_type": "business",
                "phone": "000-000",
                "address": "Phase 9 scenario credit customer",
                "credit_limit": customer_spec["credit_sale_amount"] * 2,
                "station_id": station_id,
            },
        )
        customers.append(customer)

        nozzle = nozzles[(index - 1) % len(nozzles)]
        current_setup = operator.get(f"/stations/{station_id}/setup-foundation")
        current_nozzle = next(
            item
            for item in flatten_nozzles(current_setup)
            if int(item["id"]) == int(nozzle["id"])
        )
        sale = operator.post(
            "/fuel-sales/",
            {
                "nozzle_id": current_nozzle["id"],
                "station_id": station_id,
                "fuel_type_id": current_nozzle["fuel_type_id"],
                "customer_id": customer["id"],
                "closing_meter": float(current_nozzle["meter_reading"]) + float(customer_spec["sale_liters"]),
                "rate_per_liter": customer_spec["rate_per_liter"],
                "sale_type": "credit",
                "shift_id": shift["id"],
            },
        )
        credit_sales.append(sale)

        payment = accountant.post(
            "/customer-payments/",
            {
                "customer_id": customer["id"],
                "station_id": station_id,
                "amount": customer_spec["payment_amount"],
                "payment_method": "cash",
                "reference_no": f"{scenario_id}-CPAY-{index}",
                "notes": "Created by the Phase 9 scenario runner",
            },
        )
        customer_payments.append(payment)
        customer_ledgers.append(accountant.get(f"/ledger/customer/{customer['id']}"))
        customers_after_payment.append(accountant.get(f"/customers/{customer['id']}"))

    closed_shift = operator.post(
        f"/shifts/{shift['id']}/close",
        {
            "actual_cash_collected": 0,
            "notes": f"{scenario_id} credit customer shift close",
        },
    )

    return {
        "shift": shift,
        "closed_shift": closed_shift,
        "customers": customers,
        "credit_sales": credit_sales,
        "customer_payments": customer_payments,
        "customer_ledgers": customer_ledgers,
        "customers_after_payment": customers_after_payment,
    }


def create_dips(
    *,
    manager: ApiClient,
    scenario_id: str,
    station_id: int,
    dip_specs: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    dips: list[dict[str, Any]] = []
    setup = manager.get(f"/stations/{station_id}/setup-foundation")
    tanks = setup["tanks"]
    for tank_spec in dip_specs:
        tank = tanks[int(tank_spec["tank_sequence"]) - 1]
        for reading in tank_spec["readings"]:
            current_setup = manager.get(f"/stations/{station_id}/setup-foundation")
            current_tank = next(
                item
                for item in current_setup["tanks"]
                if int(item["id"]) == int(tank["id"])
            )
            calculated_volume = float(current_tank["current_volume"]) + float(reading["calculated_volume_delta"])
            dips.append(
                manager.post(
                    "/tank-dips/",
                    {
                        "tank_id": current_tank["id"],
                        "dip_reading_mm": 100.0,
                        "calculated_volume": calculated_volume,
                        "notes": f"{scenario_id} {reading['name']} dip for {current_tank['code']}",
                    },
                )
            )
    return dips


def main() -> int:
    print("Preparing Phase 9 tenant...")
    ensure_phase9_tenant()
    manifest = load_manifest()

    anonymous = ApiClient(BASE_URL)
    anonymous.get("/health")
    head_office = anonymous.login(
        manifest["users"]["headoffice"]["username"],
        manifest["users"]["headoffice"]["password"],
    )
    manager = anonymous.login(
        manifest["users"]["base_manager"]["username"],
        manifest["users"]["base_manager"]["password"],
    )
    accountant = anonymous.login(
        manifest["users"]["accountant"]["username"],
        manifest["users"]["accountant"]["password"],
    )

    timestamp = int(time.time())
    scenario_id = f"P9-{timestamp}"
    print(f"Running dataset scenario {scenario_id}...")

    stations = head_office.get("/stations/", query={"organization_id": 4})
    if len(stations) != 1:
        raise RuntimeError(f"Expected one Phase 9 station, found {len(stations)}")
    station = stations[0]
    station_id = int(station["id"])
    organization_id = int(station["organization_id"])

    roles = head_office.get("/roles/")
    role_ids = {role["name"]: int(role["id"]) for role in roles}

    extra_users = [
        create_login_user(
            head_office=head_office,
            role_ids=role_ids,
            scenario_id=scenario_id,
            user_spec=user_spec,
            organization_id=organization_id,
            station_id=station_id,
        )
        for user_spec in manifest["users"]["extra_login_users"]
    ]
    operator_users = [
        {"username": user["username"], "password": "operator123"}
        for user in extra_users
        if user["role_id"] == role_ids["Operator"]
    ]
    required_operator_count = len(manifest["operations"]["shift_scenarios"]) + 1
    if len(operator_users) < required_operator_count:
        raise RuntimeError("Manifest must define enough fresh Operator users for shift and credit scenarios")

    employee_profiles = [
        create_employee_profile(
            client=head_office,
            scenario_id=scenario_id,
            station_id=station_id,
            profile_spec=profile_spec,
            index=index,
        )
        for index, profile_spec in enumerate(manifest["staff_profiles"], start=1)
    ]

    setup_before = manager.get(f"/stations/{station_id}/setup-foundation")
    nozzles = flatten_nozzles(setup_before)
    tanks_before_by_id = {
        int(tank["id"]): float(tank["current_volume"])
        for tank in setup_before["tanks"]
    }

    shift_results = []
    for index, shift_spec in enumerate(manifest["operations"]["shift_scenarios"]):
        shift_results.append(
            run_shift_scenario(
                anonymous=anonymous,
                scenario_id=scenario_id,
                scenario_spec=shift_spec,
                operator_user=operator_users[index % len(operator_users)],
                nozzles=nozzles,
                station_id=station_id,
            )
        )

    expenses = create_expenses(
        manager=manager,
        scenario_id=scenario_id,
        station_id=station_id,
        expense_specs=manifest["operations"]["expenses"],
    )
    purchases = create_purchases(
        manager=manager,
        scenario_id=scenario_id,
        tanks=setup_before["tanks"],
        purchase_specs=manifest["operations"]["purchases"],
    )
    supplier_finance = approve_purchases_and_pay_suppliers(
        head_office=head_office,
        accountant=accountant,
        scenario_id=scenario_id,
        station_id=station_id,
        purchases=purchases,
        supplier_specs=manifest["credit_and_ledgers"]["suppliers"],
    )
    credit_customer_flow = create_credit_customer_flow(
        anonymous=anonymous,
        accountant=accountant,
        scenario_id=scenario_id,
        operator_user=operator_users[len(manifest["operations"]["shift_scenarios"])],
        station_id=station_id,
        customer_specs=manifest["credit_and_ledgers"]["customers"],
        nozzles=nozzles,
    )
    setup_after_sales_and_approved_purchases = manager.get(f"/stations/{station_id}/setup-foundation")
    tanks_after_sales_and_approved_purchases_by_id = {
        int(tank["id"]): float(tank["current_volume"])
        for tank in setup_after_sales_and_approved_purchases["tanks"]
    }
    dips = create_dips(
        manager=manager,
        scenario_id=scenario_id,
        station_id=station_id,
        dip_specs=manifest["operations"]["dip_scenarios"],
    )

    setup_after = manager.get(f"/stations/{station_id}/setup-foundation")
    tanks_after_by_id = {
        int(tank["id"]): float(tank["current_volume"])
        for tank in setup_after["tanks"]
    }

    checks: list[dict[str, Any]] = [
        check("one-station tenant stays one station", len(stations), 1),
        check("staff profile count created", len(employee_profiles), len(manifest["staff_profiles"])),
        check("extra login users created", len(extra_users), len(manifest["users"]["extra_login_users"])),
        check("forecourt tank count", setup_before["tank_count"], manifest["forecourt"]["tank_count"]),
        check("forecourt dispenser count", setup_before["dispenser_count"], manifest["forecourt"]["dispenser_count"]),
        check("forecourt nozzle count", setup_before["nozzle_count"], manifest["forecourt"]["nozzle_count"]),
    ]

    for result, expected in zip(shift_results, manifest["operations"]["shift_scenarios"]):
        actual_sales_total = sum(float(sale["total_amount"]) for sale in result["sales"])
        actual_submitted = sum(float(item["amount"]) for item in result["cash_submissions"])
        checks.extend(
            [
                check(
                    f"{expected['name']} sales total",
                    actual_sales_total,
                    expected["expected_sales_total"],
                    approximate=True,
                ),
                check(
                    f"{expected['name']} cash submitted",
                    actual_submitted,
                    sum(expected.get("cash_submissions", [])),
                    approximate=True,
                ),
            ]
        )
        if result["closed_shift"] is not None:
            checks.extend(
                [
                    check(
                        f"{expected['name']} expected cash",
                        result["closed_shift"]["expected_cash"],
                        expected["expected_cash"],
                        approximate=True,
                    ),
                    check(
                        f"{expected['name']} difference",
                        result["closed_shift"]["difference"],
                        expected["expected_difference"],
                        approximate=True,
                    ),
                ]
            )
        else:
            shift_cash = manager.get(f"/shifts/{result['shift']['id']}/cash")
            current_cash_in_hand = shift_cash["expected_cash"] - shift_cash["cash_submitted"]
            checks.append(
                check(
                    f"{expected['name']} current backend cash in hand after submission",
                    current_cash_in_hand,
                    0.0,
                    approximate=True,
                )
            )

    for purchase, expected in zip(purchases, manifest["operations"]["purchases"]):
        checks.extend(
            [
                check(
                    f"purchase {purchase['id']} total",
                    purchase["total_amount"],
                    expected["expected_total"],
                    approximate=True,
                ),
                check(
                    f"purchase {purchase['id']} manager status",
                    purchase["status"],
                    expected["current_backend_status_for_manager"],
                ),
            ]
        )

    for approved_purchase, expected in zip(
        supplier_finance["approved_purchases"],
        manifest["operations"]["purchases"],
    ):
        checks.extend(
            [
                check(
                    f"purchase {approved_purchase['id']} approved status",
                    approved_purchase["status"],
                    "approved",
                ),
                check(
                    f"purchase {approved_purchase['id']} approved total",
                    approved_purchase["total_amount"],
                    expected["expected_total"],
                    approximate=True,
                ),
            ]
        )

    for flow_index, (customer, ledger, expected) in enumerate(
        zip(
            credit_customer_flow["customers_after_payment"],
            credit_customer_flow["customer_ledgers"],
            manifest["credit_and_ledgers"]["customers"],
        ),
        start=1,
    ):
        checks.extend(
            [
                check(
                    f"credit customer {flow_index} outstanding balance",
                    customer["outstanding_balance"],
                    expected["expected_balance_after_payment"],
                    approximate=True,
                ),
                check(
                    f"credit customer {flow_index} ledger charges",
                    ledger["summary"]["total_charges"],
                    expected["credit_sale_amount"],
                    approximate=True,
                ),
                check(
                    f"credit customer {flow_index} ledger payments",
                    ledger["summary"]["total_payments"],
                    expected["payment_amount"],
                    approximate=True,
                ),
                check(
                    f"credit customer {flow_index} ledger balance",
                    ledger["summary"]["current_balance"],
                    expected["expected_balance_after_payment"],
                    approximate=True,
                ),
            ]
        )

    for flow_index, (supplier, ledger, expected) in enumerate(
        zip(
            supplier_finance["suppliers_after_payment"],
            supplier_finance["supplier_ledgers"],
            manifest["credit_and_ledgers"]["suppliers"],
        ),
        start=1,
    ):
        checks.extend(
            [
                check(
                    f"supplier {flow_index} payable balance",
                    supplier["payable_balance"],
                    expected["expected_balance_after_payment"],
                    approximate=True,
                ),
                check(
                    f"supplier {flow_index} ledger charges",
                    ledger["summary"]["total_charges"],
                    expected["purchase_total"],
                    approximate=True,
                ),
                check(
                    f"supplier {flow_index} ledger payments",
                    ledger["summary"]["total_payments"],
                    expected["payment_amount"],
                    approximate=True,
                ),
                check(
                    f"supplier {flow_index} ledger balance",
                    ledger["summary"]["current_balance"],
                    expected["expected_balance_after_payment"],
                    approximate=True,
                ),
            ]
        )

    expected_loss_gains = [
        reading["expected_loss_gain"]
        for tank_spec in manifest["operations"]["dip_scenarios"]
        for reading in tank_spec["readings"]
    ]
    for dip, expected_loss_gain in zip(dips, expected_loss_gains):
        checks.append(
            check(
                f"dip {dip['id']} loss/gain",
                dip["loss_gain"],
                expected_loss_gain,
                approximate=True,
            )
        )

    total_sale_liters_by_tank: dict[int, float] = {}
    for result in shift_results:
        for sale in result["sales"]:
            nozzle = next(item for item in nozzles if int(item["id"]) == int(sale["nozzle_id"]))
            tank_id = int(nozzle["tank_id"])
            total_sale_liters_by_tank[tank_id] = total_sale_liters_by_tank.get(tank_id, 0.0) + float(sale["quantity"])
    for sale in credit_customer_flow["credit_sales"]:
        nozzle = next(item for item in nozzles if int(item["id"]) == int(sale["nozzle_id"]))
        tank_id = int(nozzle["tank_id"])
        total_sale_liters_by_tank[tank_id] = total_sale_liters_by_tank.get(tank_id, 0.0) + float(sale["quantity"])
    total_purchase_liters_by_tank: dict[int, float] = {}
    for purchase in supplier_finance["approved_purchases"]:
        tank_id = int(purchase["tank_id"])
        total_purchase_liters_by_tank[tank_id] = (
            total_purchase_liters_by_tank.get(tank_id, 0.0) + float(purchase["quantity"])
        )
    for tank_id, tank_before in tanks_before_by_id.items():
        expected_volume = (
            tank_before
            - total_sale_liters_by_tank.get(tank_id, 0.0)
            + total_purchase_liters_by_tank.get(tank_id, 0.0)
        )
        checks.append(
            check(
                f"tank {tank_id} volume after sales and approved purchases",
                tanks_after_sales_and_approved_purchases_by_id[tank_id],
                expected_volume,
                approximate=True,
            )
        )

    summary = {
        "scenario_id": scenario_id,
        "base_url": BASE_URL,
        "manifest_version": manifest["version"],
        "tenant": {
            "organization_id": organization_id,
            "station_id": station_id,
            "station": station["name"],
            "station_code": station["code"],
        },
        "created": {
            "extra_login_usernames": [user["username"] for user in extra_users],
            "employee_profile_ids": [profile["id"] for profile in employee_profiles],
            "shift_ids": [item["shift"]["id"] for item in shift_results],
            "fuel_sale_ids": [sale["id"] for item in shift_results for sale in item["sales"]],
            "expense_ids": [expense["id"] for expense in expenses],
            "purchase_ids": [purchase["id"] for purchase in purchases],
            "approved_purchase_ids": [purchase["id"] for purchase in supplier_finance["approved_purchases"]],
            "customer_ids": [customer["id"] for customer in credit_customer_flow["customers"]],
            "credit_fuel_sale_ids": [sale["id"] for sale in credit_customer_flow["credit_sales"]],
            "customer_payment_ids": [payment["id"] for payment in credit_customer_flow["customer_payments"]],
            "supplier_payment_ids": [payment["id"] for payment in supplier_finance["supplier_payments"]],
            "tank_dip_ids": [dip["id"] for dip in dips],
        },
        "totals": {
            "cash_fuel_sales": sum(float(sale["total_amount"]) for item in shift_results for sale in item["sales"]),
            "credit_fuel_sales": sum(float(sale["total_amount"]) for sale in credit_customer_flow["credit_sales"]),
            "cash_submitted": sum(float(cash["amount"]) for item in shift_results for cash in item["cash_submissions"]),
            "expenses": sum(float(expense["amount"]) for expense in expenses),
            "purchase_total": sum(float(purchase["total_amount"]) for purchase in purchases),
            "customer_payments": sum(float(payment["amount"]) for payment in credit_customer_flow["customer_payments"]),
            "supplier_payments": sum(float(payment["amount"]) for payment in supplier_finance["supplier_payments"]),
        },
        "known_gaps": [
            {
                "area": "open shift cash in hand",
                "current_backend_behavior": "shift_cash.expected_cash stays at opening cash until shift close",
                "desired_manifest_behavior": "expected cash should include live cash sales on open shifts",
            },
            {
                "area": "purchase approval",
                "current_backend_behavior": "Manager purchases are pending until HeadOffice approval",
                "desired_manifest_behavior": "normal purchase direct-vs-approval behavior should become a tenant/module policy",
            }
        ],
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
