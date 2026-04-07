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
from datetime import date, timedelta
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


def expect_http_error(
    name: str,
    fn,
    expected_status: int,
) -> dict[str, Any]:
    try:
        fn()
    except RuntimeError as exc:
        passed = f"failed with {expected_status}:" in str(exc)
        return {
            "name": name,
            "passed": passed,
            "expected": expected_status,
            "actual": str(exc),
        }
    return {
        "name": name,
        "passed": False,
        "expected": expected_status,
        "actual": "request succeeded",
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
            "monthly_salary": user_spec.get("monthly_salary", 0),
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
        if purchase["status"] == "approved":
            approved_purchase = purchase
        else:
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


def create_payroll_flow(
    *,
    accountant: ApiClient,
    scenario_id: str,
    timestamp: int,
    station_id: int,
    extra_users: list[dict[str, Any]],
    payroll_specs: list[dict[str, Any]],
) -> dict[str, Any]:
    period_start = date(2030, 1, 1) + timedelta(days=timestamp % 3000)
    period_end = period_start
    users_by_prefix = {
        user["username"].split(f"_{scenario_id.lower().replace('-', '_')}")[0]: user
        for user in extra_users
    }

    attendance_records: list[dict[str, Any]] = []
    salary_adjustments: list[dict[str, Any]] = []
    for payroll_spec in payroll_specs:
        user = users_by_prefix[payroll_spec["username_prefix"]]
        attendance_records.append(
            accountant.post(
                "/attendance/",
                {
                    "user_id": user["id"],
                    "station_id": station_id,
                    "attendance_date": period_start.isoformat(),
                    "status": payroll_spec["attendance_status"],
                    "notes": f"{scenario_id} payroll attendance",
                },
            )
        )
        if float(payroll_spec.get("addition", 0)) > 0:
            salary_adjustments.append(
                accountant.post(
                    "/salary-adjustments/",
                    {
                        "station_id": station_id,
                        "user_id": user["id"],
                        "effective_date": period_start.isoformat(),
                        "impact": "addition",
                        "amount": payroll_spec["addition"],
                        "reason": "Phase 9 bonus",
                        "notes": f"{scenario_id} payroll addition",
                    },
                )
            )
        if float(payroll_spec.get("deduction", 0)) > 0:
            salary_adjustments.append(
                accountant.post(
                    "/salary-adjustments/",
                    {
                        "station_id": station_id,
                        "user_id": user["id"],
                        "effective_date": period_start.isoformat(),
                        "impact": "deduction",
                        "amount": payroll_spec["deduction"],
                        "reason": "Phase 9 deduction",
                        "notes": f"{scenario_id} payroll deduction",
                    },
                )
            )

    payroll_run = accountant.post(
        "/payroll/runs",
        {
            "station_id": station_id,
            "period_start": period_start.isoformat(),
            "period_end": period_end.isoformat(),
            "notes": f"{scenario_id} Phase 9 payroll run",
        },
    )
    payroll_lines = accountant.get(f"/payroll/runs/{payroll_run['id']}/lines")
    finalized_run = accountant.post(
        f"/payroll/runs/{payroll_run['id']}/finalize",
        {"notes": f"{scenario_id} Phase 9 payroll finalized"},
    )

    return {
        "period_start": period_start.isoformat(),
        "period_end": period_end.isoformat(),
        "attendance_records": attendance_records,
        "salary_adjustments": salary_adjustments,
        "payroll_run": payroll_run,
        "payroll_lines": payroll_lines,
        "finalized_run": finalized_run,
        "target_user_ids": {
            spec["username_prefix"]: users_by_prefix[spec["username_prefix"]]["id"]
            for spec in payroll_specs
        },
    }


def create_pos_flow(
    *,
    manager: ApiClient,
    scenario_id: str,
    station_id: int,
    product_specs: list[dict[str, Any]],
) -> dict[str, Any]:
    products: list[dict[str, Any]] = []
    for index, product_spec in enumerate(product_specs, start=1):
        products.append(
            manager.post(
                "/pos-products/",
                {
                    "name": f"{scenario_id} {product_spec['product_name']}",
                    "code": f"{scenario_id}-POS-{index}",
                    "category": "lubricants",
                    "module": "mart",
                    "price": product_spec["unit_price"],
                    "stock_quantity": product_spec["stock_before"],
                    "track_inventory": True,
                    "is_active": True,
                    "station_id": station_id,
                },
            )
        )
    sale = manager.post(
        "/pos-sales/",
        {
            "station_id": station_id,
            "module": "mart",
            "payment_method": "cash",
            "customer_name": f"{scenario_id} walk-in shop customer",
            "notes": "Created by the Phase 9 scenario runner",
            "items": [
                {"product_id": product["id"], "quantity": product_spec["quantity_sold"]}
                for product, product_spec in zip(products, product_specs)
            ],
        },
    )
    products_after_sale = [manager.get(f"/pos-products/{product['id']}") for product in products]
    return {
        "products": products,
        "sale": sale,
        "products_after_sale": products_after_sale,
    }


def create_tanker_flow(
    *,
    manager: ApiClient,
    scenario_id: str,
    station_id: int,
    tanks: list[dict[str, Any]],
    tanker_manifest: dict[str, Any],
) -> dict[str, Any]:
    tankers: list[dict[str, Any]] = []
    trips: list[dict[str, Any]] = []
    completed_trips: list[dict[str, Any]] = []
    suppliers: list[dict[str, Any]] = []
    tanks_by_fuel_type = {int(tank["fuel_type_id"]): tank for tank in tanks}

    for index, tanker_spec in enumerate(tanker_manifest["fleet"], start=1):
        tank = tanks[(index - 1) % len(tanks)]
        supplier = manager.post(
            "/suppliers/",
            {
                "name": f"{scenario_id} Tanker Supplier {index}",
                "code": f"{scenario_id}-TSUP-{index}",
                "phone": "000-000",
                "address": "Phase 9 tanker supplier",
            },
        )
        suppliers.append(supplier)
        capacity = sum(float(value) for value in tanker_spec["compartments"])
        tanker = manager.post(
            "/tankers/",
            {
                "registration_no": f"{scenario_id}-{tanker_spec['vehicle_number']}",
                "name": tanker_spec["vehicle_number"],
                "capacity": capacity,
                "ownership_type": "owned" if tanker_spec["ownership_type"] == "own" else tanker_spec["ownership_type"],
                "owner_name": "Phase 9 Station" if tanker_spec["ownership_type"] == "own" else "Phase 9 Hired Owner",
                "driver_name": tanker_spec["driver_profile"],
                "driver_phone": "0300-555-0000",
                "status": "active",
                "station_id": station_id,
                "fuel_type_id": tank["fuel_type_id"],
                "compartments": [
                    {
                        "code": f"{scenario_id}-TANKER-{index}-C{compartment_index}",
                        "name": f"Compartment {compartment_index}",
                        "capacity": compartment_capacity,
                        "position": compartment_index,
                        "is_active": True,
                    }
                    for compartment_index, compartment_capacity in enumerate(tanker_spec["compartments"], start=1)
                ],
            },
        )
        tankers.append(tanker)
        transfer_tank = tanks_by_fuel_type[int(tanker["fuel_type_id"])]
        trip = manager.post(
            "/tankers/trips",
            {
                "tanker_id": tanker["id"],
                "supplier_id": supplier["id"],
                "fuel_type_id": tanker["fuel_type_id"],
                "trip_type": "supplier_to_customer",
                "destination_name": f"{scenario_id} tanker field delivery {index}",
                "notes": "Created by the Phase 9 scenario runner",
                "loaded_quantity": tanker_spec["loaded_quantity"],
                "purchase_rate": 220,
            },
        )
        trip = manager.post(
            f"/tankers/trips/{trip['id']}/deliveries",
            {
                "destination_name": f"{scenario_id} manual tanker sale {index}",
                "quantity": tanker_spec["manual_sale_quantity"],
                "fuel_rate": 300,
                "delivery_charge": 0,
                "sale_type": "cash",
                "paid_amount": tanker_spec["manual_sale_quantity"] * 300,
            },
        )
        trip = manager.post(
            f"/tankers/trips/{trip['id']}/expenses",
            {
                "expense_type": "diesel",
                "amount": tanker_spec["expense_amount"],
                "notes": "Created by the Phase 9 scenario runner",
            },
        )
        completed_trip = manager.post(
            f"/tankers/trips/{trip['id']}/complete",
            {
                "reason": "Phase 9 tanker trip complete",
                "transfer_to_tank_id": transfer_tank["id"],
                "transfer_quantity": tanker_spec["transfer_to_station_tank"],
            },
        )
        trips.append(trip)
        completed_trips.append(completed_trip)

    summary = manager.get("/tankers/summary", query={"station_id": station_id})
    return {
        "tankers": tankers,
        "suppliers": suppliers,
        "trips": trips,
        "completed_trips": completed_trips,
        "summary": summary,
    }


def create_reports_documents_notifications_flow(
    *,
    accountant: ApiClient,
    scenario_id: str,
    station_id: int,
    organization_id: int,
    shift_results: list[dict[str, Any]],
    credit_customer_flow: dict[str, Any],
    supplier_finance: dict[str, Any],
) -> dict[str, Any]:
    report_date = date.today().isoformat()
    reports = {
        "daily_closing": accountant.get(
            "/reports/daily-closing",
            query={"station_id": station_id, "report_date": report_date},
        ),
        "shift_variance": accountant.get("/reports/shift-variance", query={"station_id": station_id}),
        "stock_movement": accountant.get("/reports/stock-movement", query={"station_id": station_id}),
        "customer_balances": accountant.get("/reports/customer-balances", query={"station_id": station_id}),
        "supplier_balances": accountant.get("/reports/supplier-balances", query={"station_id": station_id}),
        "tanker_profit": accountant.get("/reports/tanker-profit", query={"station_id": station_id}),
        "tanker_deliveries": accountant.get("/reports/tanker-deliveries", query={"station_id": station_id}),
        "tanker_expenses": accountant.get("/reports/tanker-expenses", query={"station_id": station_id}),
    }
    report_definition = accountant.post(
        "/report-definitions/",
        {
            "name": f"{scenario_id} daily closing saved view",
            "report_type": "daily_closing",
            "station_id": station_id,
            "organization_id": organization_id,
            "is_shared": False,
            "filters": {"report_date": report_date, "station_id": station_id},
        },
    )
    export_job = accountant.post(
        "/report-exports/",
        {
            "report_type": "daily_closing",
            "format": "csv",
            "report_date": report_date,
            "station_id": station_id,
            "organization_id": organization_id,
        },
    )
    first_cash_sale = shift_results[0]["sales"][0]
    first_customer = credit_customer_flow["customers"][0]
    first_customer_payment = credit_customer_flow["customer_payments"][0]
    first_supplier_payment = supplier_finance["supplier_payments"][0]
    first_supplier_id = supplier_finance["approved_purchases"][0]["supplier_id"]
    documents = {
        "fuel_sale_invoice": accountant.get(f"/financial-documents/fuel-sales/{first_cash_sale['id']}"),
        "fuel_sale_einvoice": accountant.get(f"/financial-documents/fuel-sales/{first_cash_sale['id']}/einvoice"),
        "customer_payment_receipt": accountant.get(
            f"/financial-documents/customer-payments/{first_customer_payment['id']}"
        ),
        "supplier_payment_voucher": accountant.get(
            f"/financial-documents/supplier-payments/{first_supplier_payment['id']}"
        ),
        "customer_ledger": accountant.get(f"/financial-documents/customer-ledgers/{first_customer['id']}"),
        "supplier_ledger": accountant.get(
            f"/financial-documents/supplier-ledgers/{first_supplier_id}",
            query={"station_id": station_id},
        ),
    }
    notification_summary = accountant.get("/notifications/summary")
    notifications = accountant.get("/notifications/")
    return {
        "reports": reports,
        "report_definition": report_definition,
        "export_job": export_job,
        "documents": documents,
        "notification_summary": notification_summary,
        "notifications": notifications,
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


def create_corrections_flow(
    *,
    anonymous: ApiClient,
    head_office: ApiClient,
    manager: ApiClient,
    accountant: ApiClient,
    scenario_id: str,
    operator_user: dict[str, Any],
    station_id: int,
) -> dict[str, Any]:
    operator = anonymous.login(operator_user["username"], operator_user["password"])
    setup = manager.get(f"/stations/{station_id}/setup-foundation")
    tanks = setup["tanks"]
    nozzles = flatten_nozzles(setup)

    reversal_shift = operator.post(
        "/shifts/",
        {
            "station_id": station_id,
            "initial_cash": 0,
            "notes": f"{scenario_id} correction/reversal shift",
        },
    )

    customer = accountant.post(
        "/customers/",
        {
            "name": f"{scenario_id} Reversal Customer",
            "code": f"{scenario_id}-REV-CUST",
            "customer_type": "business",
            "credit_limit": 1000,
            "station_id": station_id,
        },
    )
    sale_nozzle = nozzles[0]
    current_setup = operator.get(f"/stations/{station_id}/setup-foundation")
    current_nozzle = next(
        item for item in flatten_nozzles(current_setup) if int(item["id"]) == int(sale_nozzle["id"])
    )
    reversible_credit_sale = operator.post(
        "/fuel-sales/",
        {
            "nozzle_id": current_nozzle["id"],
            "station_id": station_id,
            "fuel_type_id": current_nozzle["fuel_type_id"],
            "customer_id": customer["id"],
            "closing_meter": float(current_nozzle["meter_reading"]) + 2,
            "rate_per_liter": 250,
            "sale_type": "credit",
            "shift_id": reversal_shift["id"],
        },
    )
    customer_payment = accountant.post(
        "/customer-payments/",
        {
            "customer_id": customer["id"],
            "station_id": station_id,
            "amount": 200,
            "payment_method": "cash",
            "reference_no": f"{scenario_id}-REV-CPAY",
            "notes": "Phase 9 reversal customer payment",
        },
    )
    customer_payment_reversal_request = accountant.post(
        f"/customer-payments/{customer_payment['id']}/reverse",
        {"reason": "Phase 9 customer payment correction request"},
    )
    reversed_customer_payment = head_office.post(
        f"/customer-payments/{customer_payment['id']}/approve-reversal",
        {"reason": "Phase 9 customer payment correction approved"},
    )
    fuel_sale_reversal_request = operator.post(
        f"/fuel-sales/{reversible_credit_sale['id']}/reverse",
        {"reason": "Phase 9 credit sale correction request"},
    )
    reversed_fuel_sale = head_office.post(
        f"/fuel-sales/{reversible_credit_sale['id']}/approve-reversal",
        {"reason": "Phase 9 credit sale correction approved"},
    )
    customer_after_reversals = accountant.get(f"/customers/{customer['id']}")

    supplier = manager.post(
        "/suppliers/",
        {
            "name": f"{scenario_id} Reversal Supplier",
            "code": f"{scenario_id}-REV-SUP",
            "phone": "000-000",
            "address": "Phase 9 reversal supplier",
        },
    )
    purchase_tank = tanks[0]
    purchase = manager.post(
        "/purchases/",
        {
            "supplier_id": supplier["id"],
            "tank_id": purchase_tank["id"],
            "fuel_type_id": purchase_tank["fuel_type_id"],
            "quantity": 5,
            "rate_per_liter": 240,
            "reference_no": f"{scenario_id}-REV-PUR",
            "notes": "Phase 9 reversible purchase",
        },
    )
    approved_purchase = purchase if purchase["status"] == "approved" else head_office.post(
        f"/purchases/{purchase['id']}/approve",
        {"reason": "Phase 9 reversible purchase approved"},
    )
    supplier_payment = accountant.post(
        "/supplier-payments/",
        {
            "supplier_id": supplier["id"],
            "station_id": station_id,
            "amount": 300,
            "payment_method": "cash",
            "reference_no": f"{scenario_id}-REV-SPAY",
            "notes": "Phase 9 reversible supplier payment",
        },
    )
    supplier_payment_reversal_request = accountant.post(
        f"/supplier-payments/{supplier_payment['id']}/reverse",
        {"reason": "Phase 9 supplier payment correction request"},
    )
    reversed_supplier_payment = head_office.post(
        f"/supplier-payments/{supplier_payment['id']}/approve-reversal",
        {"reason": "Phase 9 supplier payment correction approved"},
    )
    purchase_reversal_request = manager.post(
        f"/purchases/{approved_purchase['id']}/reverse",
        {"reason": "Phase 9 purchase correction request"},
    )
    reversed_purchase = head_office.post(
        f"/purchases/{approved_purchase['id']}/approve-reversal",
        {"reason": "Phase 9 purchase correction approved"},
    )
    supplier_after_reversals = accountant.get(f"/suppliers/{supplier['id']}")

    pos_product = manager.post(
        "/pos-products/",
        {
            "name": f"{scenario_id} Reversal POS Product",
            "code": f"{scenario_id}-REV-POS",
            "category": "lubricants",
            "module": "mart",
            "price": 500,
            "stock_quantity": 10,
            "track_inventory": True,
            "is_active": True,
            "station_id": station_id,
        },
    )
    pos_sale = manager.post(
        "/pos-sales/",
        {
            "station_id": station_id,
            "module": "mart",
            "payment_method": "cash",
            "customer_name": f"{scenario_id} POS reversal customer",
            "notes": "Phase 9 reversible POS sale",
            "items": [{"product_id": pos_product["id"], "quantity": 2}],
        },
    )
    reversed_pos_sale = manager.post(f"/pos-sales/{pos_sale['id']}/reverse")
    pos_product_after_reversal = manager.get(f"/pos-products/{pos_product['id']}")

    override_customer = accountant.post(
        "/customers/",
        {
            "name": f"{scenario_id} Override Customer",
            "code": f"{scenario_id}-OVR-CUST",
            "customer_type": "business",
            "credit_limit": 100,
            "station_id": station_id,
        },
    )
    credit_override_request = manager.post(
        f"/customers/{override_customer['id']}/request-credit-override",
        {"amount": 200, "reason": "Phase 9 temporary credit limit test"},
    )
    approved_credit_override = head_office.post(
        f"/customers/{override_customer['id']}/approve-credit-override",
        {"amount": 200, "reason": "Phase 9 temporary credit limit approved"},
    )
    override_setup = operator.get(f"/stations/{station_id}/setup-foundation")
    override_nozzle = next(
        item for item in flatten_nozzles(override_setup) if int(item["id"]) == int(nozzles[1]["id"])
    )
    override_credit_sale = operator.post(
        "/fuel-sales/",
        {
            "nozzle_id": override_nozzle["id"],
            "station_id": station_id,
            "fuel_type_id": override_nozzle["fuel_type_id"],
            "customer_id": override_customer["id"],
            "closing_meter": float(override_nozzle["meter_reading"]) + 1,
            "rate_per_liter": 250,
            "sale_type": "credit",
            "shift_id": reversal_shift["id"],
        },
    )
    override_customer_after_sale = accountant.get(f"/customers/{override_customer['id']}")

    rejected_override_customer = accountant.post(
        "/customers/",
        {
            "name": f"{scenario_id} Rejected Override Customer",
            "code": f"{scenario_id}-REJ-OVR-CUST",
            "customer_type": "business",
            "credit_limit": 100,
            "station_id": station_id,
        },
    )
    rejected_credit_override_request = manager.post(
        f"/customers/{rejected_override_customer['id']}/request-credit-override",
        {"amount": 200, "reason": "Phase 9 rejection path test"},
    )
    rejected_credit_override = head_office.post(
        f"/customers/{rejected_override_customer['id']}/reject-credit-override",
        {"amount": 200, "reason": "Phase 9 override rejected as expected"},
    )

    rejection_customer = accountant.post(
        "/customers/",
        {
            "name": f"{scenario_id} Rejected Reversal Customer",
            "code": f"{scenario_id}-REJ-REV-CUST",
            "customer_type": "business",
            "credit_limit": 2000,
            "station_id": station_id,
        },
    )
    rejection_setup = operator.get(f"/stations/{station_id}/setup-foundation")
    rejection_nozzle = next(
        item for item in flatten_nozzles(rejection_setup) if int(item["id"]) == int(nozzles[3]["id"])
    )
    rejection_sale = operator.post(
        "/fuel-sales/",
        {
            "nozzle_id": rejection_nozzle["id"],
            "station_id": station_id,
            "fuel_type_id": rejection_nozzle["fuel_type_id"],
            "customer_id": rejection_customer["id"],
            "closing_meter": float(rejection_nozzle["meter_reading"]) + 1,
            "rate_per_liter": 250,
            "sale_type": "credit",
            "shift_id": reversal_shift["id"],
        },
    )
    rejected_fuel_sale_reversal_request = operator.post(
        f"/fuel-sales/{rejection_sale['id']}/reverse",
        {"reason": "Phase 9 rejected fuel sale reversal request"},
    )
    rejected_fuel_sale_reversal = head_office.post(
        f"/fuel-sales/{rejection_sale['id']}/reject-reversal",
        {"reason": "Phase 9 fuel sale reversal rejected as expected"},
    )
    rejection_customer_payment = accountant.post(
        "/customer-payments/",
        {
            "customer_id": rejection_customer["id"],
            "station_id": station_id,
            "amount": 50,
            "payment_method": "cash",
            "reference_no": f"{scenario_id}-REJ-CPAY",
            "notes": "Phase 9 rejected customer payment reversal",
        },
    )
    rejected_customer_payment_reversal_request = accountant.post(
        f"/customer-payments/{rejection_customer_payment['id']}/reverse",
        {"reason": "Phase 9 rejected customer payment reversal request"},
    )
    rejected_customer_payment_reversal = head_office.post(
        f"/customer-payments/{rejection_customer_payment['id']}/reject-reversal",
        {"reason": "Phase 9 customer payment reversal rejected as expected"},
    )

    rejection_supplier = manager.post(
        "/suppliers/",
        {
            "name": f"{scenario_id} Rejected Reversal Supplier",
            "code": f"{scenario_id}-REJ-REV-SUP",
            "phone": "000-000",
            "address": "Phase 9 rejected reversal supplier",
        },
    )
    rejection_purchase = manager.post(
        "/purchases/",
        {
            "supplier_id": rejection_supplier["id"],
            "tank_id": purchase_tank["id"],
            "fuel_type_id": purchase_tank["fuel_type_id"],
            "quantity": 5,
            "rate_per_liter": 240,
            "reference_no": f"{scenario_id}-REJ-PUR",
            "notes": "Phase 9 rejected purchase reversal",
        },
    )
    rejected_purchase_reversal_request = manager.post(
        f"/purchases/{rejection_purchase['id']}/reverse",
        {"reason": "Phase 9 rejected purchase reversal request"},
    )
    rejected_purchase_reversal = head_office.post(
        f"/purchases/{rejection_purchase['id']}/reject-reversal",
        {"reason": "Phase 9 purchase reversal rejected as expected"},
    )
    rejection_supplier_payment = accountant.post(
        "/supplier-payments/",
        {
            "supplier_id": rejection_supplier["id"],
            "station_id": station_id,
            "amount": 50,
            "payment_method": "cash",
            "reference_no": f"{scenario_id}-REJ-SPAY",
            "notes": "Phase 9 rejected supplier payment reversal",
        },
    )
    rejected_supplier_payment_reversal_request = accountant.post(
        f"/supplier-payments/{rejection_supplier_payment['id']}/reverse",
        {"reason": "Phase 9 rejected supplier payment reversal request"},
    )
    rejected_supplier_payment_reversal = head_office.post(
        f"/supplier-payments/{rejection_supplier_payment['id']}/reject-reversal",
        {"reason": "Phase 9 supplier payment reversal rejected as expected"},
    )

    internal_tank = tanks[1 if len(tanks) > 1 else 0]
    internal_usage = manager.post(
        "/internal-fuel-usage/",
        {
            "tank_id": internal_tank["id"],
            "fuel_type_id": internal_tank["fuel_type_id"],
            "quantity": 10,
            "purpose": "generator testing",
            "notes": "Phase 9 internal fuel usage",
        },
    )
    internal_usage_list = manager.get("/internal-fuel-usage/", query={"station_id": station_id})

    meter_setup = head_office.get(f"/stations/{station_id}/setup-foundation")
    meter_nozzle = next(
        item for item in flatten_nozzles(meter_setup) if int(item["id"]) == int(nozzles[2]["id"])
    )
    meter_adjustment = head_office.post(
        f"/nozzles/{meter_nozzle['id']}/adjust-meter",
        {
            "new_reading": float(meter_nozzle["meter_reading"]) + 100,
            "reason": "Phase 9 meter reset test",
        },
    )
    meter_adjustments = head_office.get(f"/nozzles/{meter_nozzle['id']}/adjustments")
    meter_segments = head_office.get(f"/nozzles/{meter_nozzle['id']}/segments")

    return {
        "reversal_shift": reversal_shift,
        "customer": customer,
        "reversible_credit_sale": reversible_credit_sale,
        "customer_payment": customer_payment,
        "customer_payment_reversal_request": customer_payment_reversal_request,
        "reversed_customer_payment": reversed_customer_payment,
        "fuel_sale_reversal_request": fuel_sale_reversal_request,
        "reversed_fuel_sale": reversed_fuel_sale,
        "customer_after_reversals": customer_after_reversals,
        "supplier": supplier,
        "purchase": purchase,
        "approved_purchase": approved_purchase,
        "supplier_payment": supplier_payment,
        "supplier_payment_reversal_request": supplier_payment_reversal_request,
        "reversed_supplier_payment": reversed_supplier_payment,
        "purchase_reversal_request": purchase_reversal_request,
        "reversed_purchase": reversed_purchase,
        "supplier_after_reversals": supplier_after_reversals,
        "pos_product": pos_product,
        "pos_sale": pos_sale,
        "reversed_pos_sale": reversed_pos_sale,
        "pos_product_after_reversal": pos_product_after_reversal,
        "override_customer": override_customer,
        "credit_override_request": credit_override_request,
        "approved_credit_override": approved_credit_override,
        "override_credit_sale": override_credit_sale,
        "override_customer_after_sale": override_customer_after_sale,
        "rejected_credit_override_request": rejected_credit_override_request,
        "rejected_credit_override": rejected_credit_override,
        "rejection_sale": rejection_sale,
        "rejected_fuel_sale_reversal_request": rejected_fuel_sale_reversal_request,
        "rejected_fuel_sale_reversal": rejected_fuel_sale_reversal,
        "rejected_customer_payment_reversal_request": rejected_customer_payment_reversal_request,
        "rejected_customer_payment_reversal": rejected_customer_payment_reversal,
        "rejection_purchase": rejection_purchase,
        "rejected_purchase_reversal_request": rejected_purchase_reversal_request,
        "rejected_purchase_reversal": rejected_purchase_reversal,
        "rejected_supplier_payment_reversal_request": rejected_supplier_payment_reversal_request,
        "rejected_supplier_payment_reversal": rejected_supplier_payment_reversal,
        "internal_usage": internal_usage,
        "internal_usage_list": internal_usage_list,
        "meter_adjustment": meter_adjustment,
        "meter_adjustments": meter_adjustments,
        "meter_segments": meter_segments,
    }


def create_scope_and_module_flow(*, anonymous: ApiClient) -> dict[str, Any]:
    multi_head_office = anonymous.login("p9_multi", "office123")
    station_a_admin = anonymous.login("p9_multi_station_a_admin", "station123")
    station_b_admin = anonymous.login("p9_multi_station_b_admin", "station123")
    minimal_head_office = anonymous.login("p9_minimal", "office123")

    multi_orgs = multi_head_office.get("/organizations/")
    multi_org = multi_orgs[0]
    multi_stations_for_head_office = multi_head_office.get(
        "/stations/",
        query={"organization_id": multi_org["id"]},
    )
    multi_stations_for_station_a = station_a_admin.get("/stations/")
    station_a = next(item for item in multi_stations_for_head_office if item["code"] == "PHASE9-MULTI-A")
    station_b = next(item for item in multi_stations_for_head_office if item["code"] == "PHASE9-MULTI-B")
    station_a_modules = multi_head_office.get(f"/station-modules/{station_a['id']}")
    station_b_modules = multi_head_office.get(f"/station-modules/{station_b['id']}")

    minimal_orgs = minimal_head_office.get("/organizations/")
    minimal_org = minimal_orgs[0]
    minimal_stations = minimal_head_office.get("/stations/", query={"organization_id": minimal_org["id"]})
    minimal_station = minimal_stations[0]
    minimal_modules = minimal_head_office.get(f"/station-modules/{minimal_station['id']}")

    leakage_checks = [
        expect_http_error(
            "StationAdmin A cannot read Station B",
            lambda: station_a_admin.get(f"/stations/{station_b['id']}"),
            403,
        ),
        expect_http_error(
            "StationAdmin A cannot list users for Station B",
            lambda: station_a_admin.get("/users/", query={"station_id": station_b["id"]}),
            403,
        ),
        expect_http_error(
            "StationAdmin B cannot read Station A",
            lambda: station_b_admin.get(f"/stations/{station_a['id']}"),
            403,
        ),
    ]

    return {
        "multi_org": multi_org,
        "multi_stations_for_head_office": multi_stations_for_head_office,
        "multi_stations_for_station_a": multi_stations_for_station_a,
        "station_a": station_a,
        "station_b": station_b,
        "station_a_modules": station_a_modules,
        "station_b_modules": station_b_modules,
        "minimal_org": minimal_org,
        "minimal_station": minimal_station,
        "minimal_modules": minimal_modules,
        "leakage_checks": leakage_checks,
    }


def main() -> int:
    print("Preparing Phase 9 tenant...")
    os.environ["PPMS_RESET_PHASE9_FORECOURT"] = "1"
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
    payroll_flow = create_payroll_flow(
        accountant=accountant,
        scenario_id=scenario_id,
        timestamp=timestamp,
        station_id=station_id,
        extra_users=extra_users,
        payroll_specs=manifest["payroll"],
    )
    pos_flow = create_pos_flow(
        manager=manager,
        scenario_id=scenario_id,
        station_id=station_id,
        product_specs=manifest["pos"]["products"],
    )
    tanker_flow = create_tanker_flow(
        manager=manager,
        scenario_id=scenario_id,
        station_id=station_id,
        tanks=setup_before["tanks"],
        tanker_manifest=manifest["tankers"],
    )
    corrections_flow = create_corrections_flow(
        anonymous=anonymous,
        head_office=head_office,
        manager=manager,
        accountant=accountant,
        scenario_id=scenario_id,
        operator_user=operator_users[0],
        station_id=station_id,
    )
    scope_and_module_flow = create_scope_and_module_flow(anonymous=anonymous)
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
    reports_documents_notifications = create_reports_documents_notifications_flow(
        accountant=accountant,
        scenario_id=scenario_id,
        station_id=station_id,
        organization_id=organization_id,
        shift_results=shift_results,
        credit_customer_flow=credit_customer_flow,
        supplier_finance=supplier_finance,
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
                    f"{expected['name']} cash in hand after submission",
                    current_cash_in_hand,
                    expected["expected_cash_in_hand_after_submission"],
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

    lines_by_user_id = {
        int(line["user_id"]): line
        for line in payroll_flow["payroll_lines"]
    }
    expected_payroll_net_total = 0.0
    for payroll_spec in manifest["payroll"]:
        user_id = payroll_flow["target_user_ids"][payroll_spec["username_prefix"]]
        line = lines_by_user_id[user_id]
        expected_payroll_net_total += float(payroll_spec["expected_net_salary"])
        checks.extend(
            [
                check(
                    f"payroll {payroll_spec['username_prefix']} monthly salary",
                    line["monthly_salary"],
                    payroll_spec["monthly_salary"],
                    approximate=True,
                ),
                check(
                    f"payroll {payroll_spec['username_prefix']} net salary",
                    line["net_amount"],
                    payroll_spec["expected_net_salary"],
                    approximate=True,
                ),
            ]
        )
    checks.extend(
        [
            check(
                "payroll target attendance records",
                len(payroll_flow["attendance_records"]),
                len(manifest["payroll"]),
            ),
            check(
                "payroll run finalized",
                payroll_flow["finalized_run"]["status"],
                "finalized",
            ),
            check(
                "payroll run net amount",
                payroll_flow["payroll_run"]["total_net_amount"],
                expected_payroll_net_total,
                approximate=True,
            ),
        ]
    )

    pos_expected_total = sum(
        float(product["quantity_sold"]) * float(product["unit_price"])
        for product in manifest["pos"]["products"]
    )
    checks.append(
        check(
            "POS sale total",
            pos_flow["sale"]["total_amount"],
            pos_expected_total,
            approximate=True,
        )
    )
    for product_after_sale, product_spec in zip(pos_flow["products_after_sale"], manifest["pos"]["products"]):
        checks.append(
            check(
                f"POS product {product_after_sale['id']} stock after sale",
                product_after_sale["stock_quantity"],
                product_spec["expected_stock_after_sale"],
                approximate=True,
            )
        )

    expected_loaded_quantity = sum(float(item["loaded_quantity"]) for item in manifest["tankers"]["fleet"])
    expected_manual_sale_quantity = sum(float(item["manual_sale_quantity"]) for item in manifest["tankers"]["fleet"])
    expected_transferred_quantity = sum(
        float(item["transfer_to_station_tank"]) for item in manifest["tankers"]["fleet"]
    )
    expected_leftover_quantity = sum(
        float(item["expected_leftover_quantity"]) for item in manifest["tankers"]["fleet"]
    )
    scenario_tanker_loaded_quantity = sum(float(trip["loaded_quantity"] or 0) for trip in tanker_flow["completed_trips"])
    scenario_tanker_delivered_quantity = sum(float(trip["total_quantity"]) for trip in tanker_flow["completed_trips"])
    scenario_tanker_transferred_quantity = sum(float(trip["transferred_quantity"]) for trip in tanker_flow["completed_trips"])
    checks.extend(
        [
            check("tanker count created", len(tanker_flow["tankers"]), len(manifest["tankers"]["fleet"])),
            check(
                "scenario tanker completed trip count",
                len(tanker_flow["completed_trips"]),
                len(manifest["tankers"]["fleet"]),
            ),
            check(
                "scenario tanker loaded quantity",
                scenario_tanker_loaded_quantity,
                expected_loaded_quantity,
                approximate=True,
            ),
            check(
                "scenario tanker delivered quantity",
                scenario_tanker_delivered_quantity,
                expected_manual_sale_quantity,
                approximate=True,
            ),
            check(
                "scenario tanker transferred quantity",
                scenario_tanker_transferred_quantity,
                expected_transferred_quantity,
                approximate=True,
            ),
            check(
                "scenario tanker remaining leftover quantity",
                sum(float(trip["leftover_quantity"]) for trip in tanker_flow["completed_trips"]),
                expected_leftover_quantity,
                approximate=True,
            ),
        ]
    )

    report_checks = reports_documents_notifications["reports"]
    checks.extend(
        [
            check("daily closing report station scope", report_checks["daily_closing"].get("station_id"), station_id),
            check("customer balance report has rows", len(report_checks["customer_balances"].get("items", [])) >= 2, True),
            check("supplier balance report has rows", len(report_checks["supplier_balances"].get("items", [])) >= 2, True),
            check("tanker profit report has rows", len(report_checks["tanker_profit"].get("items", [])) >= 2, True),
            check("report definition created", reports_documents_notifications["report_definition"]["report_type"], "daily_closing"),
            check("report export completed", reports_documents_notifications["export_job"]["status"], "completed"),
        ]
    )
    document_checks = reports_documents_notifications["documents"]
    checks.extend(
        [
            check("fuel sale document type", document_checks["fuel_sale_invoice"]["document_type"], "fuel_sale_invoice"),
            check("customer payment document type", document_checks["customer_payment_receipt"]["document_type"], "customer_payment_receipt"),
            check("supplier payment document type", document_checks["supplier_payment_voucher"]["document_type"], "supplier_payment_voucher"),
            check("customer ledger document type", document_checks["customer_ledger"]["document_type"], "customer_ledger_statement"),
            check("supplier ledger document type", document_checks["supplier_ledger"]["document_type"], "supplier_ledger_statement"),
        ]
    )
    checks.append(
        check(
            "notification summary readable",
            "unread" in reports_documents_notifications["notification_summary"]
            and "total" in reports_documents_notifications["notification_summary"],
            True,
        )
    )
    checks.extend(
        [
            check(
                "customer payment reversal requested",
                corrections_flow["customer_payment_reversal_request"]["reversal_request_status"],
                "pending",
            ),
            check(
                "customer payment reversed",
                corrections_flow["reversed_customer_payment"]["is_reversed"],
                True,
            ),
            check(
                "fuel sale reversal requested",
                corrections_flow["fuel_sale_reversal_request"]["reversal_request_status"],
                "pending",
            ),
            check("fuel sale reversed", corrections_flow["reversed_fuel_sale"]["is_reversed"], True),
            check(
                "reversal customer balance restored",
                corrections_flow["customer_after_reversals"]["outstanding_balance"],
                0.0,
                approximate=True,
            ),
            check(
                "supplier payment reversal requested",
                corrections_flow["supplier_payment_reversal_request"]["reversal_request_status"],
                "pending",
            ),
            check(
                "supplier payment reversed",
                corrections_flow["reversed_supplier_payment"]["is_reversed"],
                True,
            ),
            check(
                "purchase reversal requested",
                corrections_flow["purchase_reversal_request"]["reversal_request_status"],
                "pending",
            ),
            check("purchase reversed", corrections_flow["reversed_purchase"]["is_reversed"], True),
            check(
                "reversal supplier payable restored",
                corrections_flow["supplier_after_reversals"]["payable_balance"],
                0.0,
                approximate=True,
            ),
            check("POS sale reversed", corrections_flow["reversed_pos_sale"]["is_reversed"], True),
            check(
                "POS stock restored after reversal",
                corrections_flow["pos_product_after_reversal"]["stock_quantity"],
                corrections_flow["pos_product"]["stock_quantity"],
                approximate=True,
            ),
            check(
                "credit override requested",
                corrections_flow["credit_override_request"]["credit_override_status"],
                "pending",
            ),
            check(
                "credit override approved",
                corrections_flow["approved_credit_override"]["credit_override_status"],
                "approved",
            ),
            check(
                "credit override rejection requested",
                corrections_flow["rejected_credit_override_request"]["credit_override_status"],
                "pending",
            ),
            check(
                "credit override rejected",
                corrections_flow["rejected_credit_override"]["credit_override_status"],
                "rejected",
            ),
            check(
                "credit override sale created above base limit",
                corrections_flow["override_credit_sale"]["total_amount"],
                250.0,
                approximate=True,
            ),
            check(
                "fuel sale reversal rejection requested",
                corrections_flow["rejected_fuel_sale_reversal_request"]["reversal_request_status"],
                "pending",
            ),
            check(
                "fuel sale reversal rejected",
                corrections_flow["rejected_fuel_sale_reversal"]["reversal_request_status"],
                "rejected",
            ),
            check(
                "customer payment reversal rejection requested",
                corrections_flow["rejected_customer_payment_reversal_request"]["reversal_request_status"],
                "pending",
            ),
            check(
                "customer payment reversal rejected",
                corrections_flow["rejected_customer_payment_reversal"]["reversal_request_status"],
                "rejected",
            ),
            check(
                "purchase reversal rejection requested",
                corrections_flow["rejected_purchase_reversal_request"]["reversal_request_status"],
                "pending",
            ),
            check(
                "purchase reversal rejected",
                corrections_flow["rejected_purchase_reversal"]["reversal_request_status"],
                "rejected",
            ),
            check(
                "supplier payment reversal rejection requested",
                corrections_flow["rejected_supplier_payment_reversal_request"]["reversal_request_status"],
                "pending",
            ),
            check(
                "supplier payment reversal rejected",
                corrections_flow["rejected_supplier_payment_reversal"]["reversal_request_status"],
                "rejected",
            ),
            check(
                "override customer balance after override sale",
                corrections_flow["override_customer_after_sale"]["outstanding_balance"],
                250.0,
                approximate=True,
            ),
            check(
                "internal fuel usage quantity",
                corrections_flow["internal_usage"]["quantity"],
                10.0,
                approximate=True,
            ),
            check(
                "internal fuel usage list readable",
                len(corrections_flow["internal_usage_list"]) >= 1,
                True,
            ),
            check(
                "meter adjustment old-to-new delta",
                float(corrections_flow["meter_adjustment"]["new_reading"])
                - float(corrections_flow["meter_adjustment"]["old_reading"]),
                100.0,
                approximate=True,
            ),
            check(
                "meter adjustment history readable",
                len(corrections_flow["meter_adjustments"]) >= 1,
                True,
            ),
            check(
                "meter segments readable after adjustment",
                len(corrections_flow["meter_segments"]) >= 1,
                True,
            ),
        ]
    )
    station_a_modules = {
        item["module_name"]: bool(item["is_enabled"])
        for item in scope_and_module_flow["station_a_modules"]
    }
    station_b_modules = {
        item["module_name"]: bool(item["is_enabled"])
        for item in scope_and_module_flow["station_b_modules"]
    }
    minimal_modules = {
        item["module_name"]: bool(item["is_enabled"])
        for item in scope_and_module_flow["minimal_modules"]
    }
    checks.extend(
        [
            check(
                "multi-station HeadOffice sees both stations",
                len(scope_and_module_flow["multi_stations_for_head_office"]),
                2,
            ),
            check(
                "multi-station StationAdmin A sees only own station",
                [item["code"] for item in scope_and_module_flow["multi_stations_for_station_a"]],
                ["PHASE9-MULTI-A"],
            ),
            check(
                "multi-station StationAdmin role appears only in multi-station dataset",
                scope_and_module_flow["station_a"]["code"],
                "PHASE9-MULTI-A",
            ),
            check("multi station A tanker enabled", station_a_modules.get("tanker_operations"), True),
            check("multi station B tanker disabled", station_b_modules.get("tanker_operations"), False),
            check("minimal tenant remains one station", scope_and_module_flow["minimal_org"]["station_target_count"], 1),
            check("minimal tenant POS disabled", minimal_modules.get("pos"), False),
            check("minimal tenant mart disabled", minimal_modules.get("mart"), False),
            check("minimal tenant tanker disabled", minimal_modules.get("tanker_operations"), False),
            check("minimal tenant hardware disabled", minimal_modules.get("hardware"), False),
            check("minimal tenant meter adjustments disabled", minimal_modules.get("meter_adjustments"), False),
        ]
    )
    checks.extend(scope_and_module_flow["leakage_checks"])

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
    override_sale = corrections_flow["override_credit_sale"]
    override_nozzle = next(item for item in nozzles if int(item["id"]) == int(override_sale["nozzle_id"]))
    override_tank_id = int(override_nozzle["tank_id"])
    total_sale_liters_by_tank[override_tank_id] = (
        total_sale_liters_by_tank.get(override_tank_id, 0.0) + float(override_sale["quantity"])
    )
    rejection_sale = corrections_flow["rejection_sale"]
    rejection_nozzle = next(item for item in nozzles if int(item["id"]) == int(rejection_sale["nozzle_id"]))
    rejection_tank_id = int(rejection_nozzle["tank_id"])
    total_sale_liters_by_tank[rejection_tank_id] = (
        total_sale_liters_by_tank.get(rejection_tank_id, 0.0) + float(rejection_sale["quantity"])
    )
    total_purchase_liters_by_tank: dict[int, float] = {}
    for purchase in supplier_finance["approved_purchases"]:
        tank_id = int(purchase["tank_id"])
        total_purchase_liters_by_tank[tank_id] = (
            total_purchase_liters_by_tank.get(tank_id, 0.0) + float(purchase["quantity"])
        )
    rejection_purchase = corrections_flow["rejection_purchase"]
    total_purchase_liters_by_tank[int(rejection_purchase["tank_id"])] = (
        total_purchase_liters_by_tank.get(int(rejection_purchase["tank_id"]), 0.0)
        + float(rejection_purchase["quantity"])
    )
    total_tanker_transfer_liters_by_tank: dict[int, float] = {}
    for completed_trip in tanker_flow["completed_trips"]:
        tank_id = completed_trip.get("transfer_tank_id")
        if tank_id is None:
            continue
        total_tanker_transfer_liters_by_tank[int(tank_id)] = (
            total_tanker_transfer_liters_by_tank.get(int(tank_id), 0.0)
            + float(completed_trip["transferred_quantity"])
        )
    internal_usage_liters_by_tank = {
        int(corrections_flow["internal_usage"]["tank_id"]): float(corrections_flow["internal_usage"]["quantity"])
    }
    for tank_id, tank_before in tanks_before_by_id.items():
        expected_volume = (
            tank_before
            - total_sale_liters_by_tank.get(tank_id, 0.0)
            + total_purchase_liters_by_tank.get(tank_id, 0.0)
            + total_tanker_transfer_liters_by_tank.get(tank_id, 0.0)
            - internal_usage_liters_by_tank.get(tank_id, 0.0)
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
            "attendance_record_ids": [record["id"] for record in payroll_flow["attendance_records"]],
            "salary_adjustment_ids": [adjustment["id"] for adjustment in payroll_flow["salary_adjustments"]],
            "payroll_run_id": payroll_flow["payroll_run"]["id"],
            "pos_product_ids": [product["id"] for product in pos_flow["products"]],
            "pos_sale_id": pos_flow["sale"]["id"],
            "tanker_ids": [tanker["id"] for tanker in tanker_flow["tankers"]],
            "tanker_trip_ids": [trip["id"] for trip in tanker_flow["completed_trips"]],
            "report_definition_id": reports_documents_notifications["report_definition"]["id"],
            "report_export_id": reports_documents_notifications["export_job"]["id"],
            "tank_dip_ids": [dip["id"] for dip in dips],
            "correction_ids": {
                "reversed_fuel_sale_id": corrections_flow["reversed_fuel_sale"]["id"],
                "reversed_purchase_id": corrections_flow["reversed_purchase"]["id"],
                "reversed_customer_payment_id": corrections_flow["reversed_customer_payment"]["id"],
                "reversed_supplier_payment_id": corrections_flow["reversed_supplier_payment"]["id"],
                "reversed_pos_sale_id": corrections_flow["reversed_pos_sale"]["id"],
                "credit_override_customer_id": corrections_flow["override_customer"]["id"],
                "internal_fuel_usage_id": corrections_flow["internal_usage"]["id"],
                "meter_adjustment_id": corrections_flow["meter_adjustment"]["id"],
            },
            "scope_module_dataset": {
                "multi_org_id": scope_and_module_flow["multi_org"]["id"],
                "multi_station_ids": [
                    item["id"] for item in scope_and_module_flow["multi_stations_for_head_office"]
                ],
                "minimal_org_id": scope_and_module_flow["minimal_org"]["id"],
                "minimal_station_id": scope_and_module_flow["minimal_station"]["id"],
            },
        },
        "totals": {
            "cash_fuel_sales": sum(float(sale["total_amount"]) for item in shift_results for sale in item["sales"]),
            "credit_fuel_sales": sum(float(sale["total_amount"]) for sale in credit_customer_flow["credit_sales"]),
            "cash_submitted": sum(float(cash["amount"]) for item in shift_results for cash in item["cash_submissions"]),
            "expenses": sum(float(expense["amount"]) for expense in expenses),
            "purchase_total": sum(float(purchase["total_amount"]) for purchase in purchases),
            "customer_payments": sum(float(payment["amount"]) for payment in credit_customer_flow["customer_payments"]),
            "supplier_payments": sum(float(payment["amount"]) for payment in supplier_finance["supplier_payments"]),
            "payroll_net": payroll_flow["payroll_run"]["total_net_amount"],
            "pos_sales": pos_flow["sale"]["total_amount"],
            "scenario_tanker_loaded_quantity": sum(
                float(trip["loaded_quantity"] or 0) for trip in tanker_flow["completed_trips"]
            ),
            "scenario_tanker_transferred_quantity": sum(
                float(trip["transferred_quantity"]) for trip in tanker_flow["completed_trips"]
            ),
            "internal_fuel_usage": corrections_flow["internal_usage"]["quantity"],
            "credit_override_sale": corrections_flow["override_credit_sale"]["total_amount"],
        },
        "known_gaps": [
            {
                "area": "profile-only payroll",
                "current_backend_behavior": "payroll runs calculate from payroll-enabled login users only",
                "desired_manifest_behavior": "profile-only staff payroll should be supported or clearly separated in UI",
            },
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
