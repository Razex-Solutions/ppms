"""Run repeatable StationAdmin backend smoke checks against the live API.

Run from the repository root while the backend is running:
    venv\\Scripts\\python.exe scripts\\run_station_admin_smoke.py

Optional:
    venv\\Scripts\\python.exe scripts\\run_station_admin_smoke.py --include-tanker

Default behavior:
- performs cleanup-safe mutating checks for StationAdmin workflows
- restores invoice/template edits
- deletes created user/profile/supplier/item records
- skips tanker mutating flow unless explicitly enabled because tanker history
  is intentionally persistent
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT / "scripts" / "station_admin_smoke_last.json"

sys.path.insert(0, str(ROOT / "scripts"))

from run_phase9_scenario import ApiClient, BASE_URL  # noqa: E402


def _now_suffix() -> str:
    return str(int(time.time()))


@dataclass
class SmokeResult:
    name: str
    passed: bool
    details: str


@dataclass
class SmokeContext:
    client: ApiClient
    station_id: int
    organization_id: int
    report: list[SmokeResult] = field(default_factory=list)
    cleanup_actions: list[tuple[str, Any]] = field(default_factory=list)

    def ok(self, name: str, details: str) -> None:
        self.report.append(SmokeResult(name=name, passed=True, details=details))

    def fail(self, name: str, details: str) -> None:
        self.report.append(SmokeResult(name=name, passed=False, details=details))

    def record_cleanup(self, label: str, fn) -> None:
        self.cleanup_actions.append((label, fn))

    def run_cleanup(self) -> None:
        while self.cleanup_actions:
            label, fn = self.cleanup_actions.pop()
            try:
                fn()
                self.ok(f"cleanup:{label}", "Cleanup completed.")
            except Exception as exc:  # noqa: BLE001
                self.fail(f"cleanup:{label}", str(exc))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default=BASE_URL)
    parser.add_argument("--username", default="stationadmin")
    parser.add_argument("--password", default="station123")
    parser.add_argument(
        "--include-tanker",
        action="store_true",
        help="Run tanker trip create/delivery/payment/expense/complete flow. This leaves history.",
    )
    parser.add_argument(
        "--write-report",
        default=str(REPORT_PATH),
        help="JSON report path.",
    )
    return parser.parse_args()


def assert_true(ctx: SmokeContext, name: str, condition: bool, details: str) -> None:
    if condition:
        ctx.ok(name, details)
    else:
        ctx.fail(name, details)
        raise RuntimeError(details)


def first(items: list[dict[str, Any]], predicate) -> dict[str, Any]:
    for item in items:
        if predicate(item):
            return item
    raise RuntimeError("Expected item was not found.")


def get_station_context(client: ApiClient) -> tuple[int, int]:
    me = client.get("/auth/me")
    station_id = me.get("station_id")
    organization_id = me.get("organization_id")
    if station_id is None or organization_id is None:
        raise RuntimeError("StationAdmin login does not have station/org scope.")
    return int(station_id), int(organization_id)


def smoke_auth_and_reads(ctx: SmokeContext) -> None:
    me = ctx.client.get("/auth/me")
    assert_true(
        ctx,
        "auth:stationadmin",
        str(me.get("role_name")) == "StationAdmin",
        f"Expected StationAdmin role, got {me.get('role_name')}",
    )
    dashboard = ctx.client.get(
        "/dashboard/",
        query={"station_id": ctx.station_id},
    )
    assert_true(
        ctx,
        "read:dashboard",
        isinstance(dashboard, dict),
        "Station dashboard payload should be an object.",
    )
    users = ctx.client.get("/users/", query={"station_id": ctx.station_id})
    profiles = ctx.client.get("/employee-profiles/", query={"station_id": ctx.station_id})
    fuel_types = ctx.client.get("/fuel-types/")
    tanks = ctx.client.get("/tanks/", query={"station_id": ctx.station_id})
    nozzles = ctx.client.get("/nozzles/", query={"station_id": ctx.station_id})
    assert_true(ctx, "read:users", len(users) >= 1, "Expected at least one station user.")
    assert_true(
        ctx,
        "read:employee_profiles",
        len(profiles) >= 1,
        "Expected at least one employee profile.",
    )
    assert_true(ctx, "read:fuel_types", len(fuel_types) >= 1, "Expected fuel types.")
    assert_true(ctx, "read:tanks", len(tanks) >= 1, "Expected tanks.")
    assert_true(ctx, "read:nozzles", len(nozzles) >= 1, "Expected nozzles.")


def smoke_user_and_profile_crud(ctx: SmokeContext, suffix: str) -> None:
    roles = ctx.client.get("/roles/")
    operator_role = first(roles, lambda item: str(item.get("name")) == "Operator")
    username = f"sa_smoke_{suffix}"
    created_user = ctx.client.post(
        "/users/",
        {
            "full_name": "Station Smoke User",
            "username": username,
            "email": f"{username}@example.com",
            "password": "cash1234",
            "role_id": operator_role["id"],
            "organization_id": ctx.organization_id,
            "station_id": ctx.station_id,
            "scope_level": "station",
            "monthly_salary": 45000,
            "payroll_enabled": True,
        },
    )
    user_id = int(created_user["id"])
    ctx.record_cleanup("user", lambda: ctx.client.request("DELETE", f"/users/{user_id}"))
    assert_true(
        ctx,
        "create:user",
        str(created_user.get("username")) == username,
        f"Created user should be {username}",
    )

    updated_user = ctx.client.put(
        f"/users/{user_id}",
        {
            "full_name": "Station Smoke User Updated",
            "monthly_salary": 47000,
            "payroll_enabled": False,
            "is_active": True,
            "role_id": operator_role["id"],
            "station_id": ctx.station_id,
        },
    )
    assert_true(
        ctx,
        "update:user",
        str(updated_user.get("full_name")) == "Station Smoke User Updated",
        "User full name should update.",
    )

    created_profile = ctx.client.post(
        "/employee-profiles/",
        {
            "station_id": ctx.station_id,
            "linked_user_id": user_id,
            "full_name": "Station Smoke User Updated",
            "staff_type": "Staff",
            "staff_title": "Cashier",
            "employee_code": f"EMP-SA-{suffix}",
            "phone": "0300-0000000",
            "monthly_salary": 47000,
            "payroll_enabled": True,
            "can_login": True,
            "notes": "station admin smoke",
        },
    )
    profile_id = int(created_profile["id"])
    ctx.record_cleanup(
        "employee_profile",
        lambda: ctx.client.request("DELETE", f"/employee-profiles/{profile_id}"),
    )
    assert_true(
        ctx,
        "create:employee_profile",
        str(created_profile.get("staff_title")) == "Cashier",
        "Employee profile title should be Cashier.",
    )

    updated_profile = ctx.client.put(
        f"/employee-profiles/{profile_id}",
        {
            "staff_title": "Senior Cashier",
            "monthly_salary": 50000,
            "payroll_enabled": False,
            "can_login": True,
            "is_active": True,
        },
    )
    assert_true(
        ctx,
        "update:employee_profile",
        str(updated_profile.get("staff_title")) == "Senior Cashier",
        "Employee profile title should update.",
    )


def smoke_supplier_crud(ctx: SmokeContext, suffix: str) -> None:
    code = f"SUP-SA-{suffix}"
    created = ctx.client.post(
        "/suppliers/",
        {
            "name": "Station Smoke Supplier",
            "code": code,
            "phone": "0300-1111111",
            "address": "Station smoke supplier",
        },
    )
    supplier_id = int(created["id"])
    ctx.record_cleanup("supplier", lambda: ctx.client.request("DELETE", f"/suppliers/{supplier_id}"))
    assert_true(
        ctx,
        "create:supplier",
        str(created.get("code")) == code,
        "Supplier code should match the smoke code.",
    )
    updated = ctx.client.put(
        f"/suppliers/{supplier_id}",
        {
            "phone": "0300-2222222",
            "address": "Updated station smoke supplier",
        },
    )
    assert_true(
        ctx,
        "update:supplier",
        str(updated.get("phone")) == "0300-2222222",
        "Supplier phone should update.",
    )


def smoke_inventory_crud(ctx: SmokeContext, suffix: str) -> None:
    created = ctx.client.post(
        "/pos-products/",
        {
            "station_id": ctx.station_id,
            "name": f"Coolant Smoke {suffix}",
            "code": f"POS-SA-{suffix}",
            "category": "Lubricants",
            "module": "service_station",
            "buying_price": 900,
            "price": 1200,
            "stock_quantity": 15,
            "is_active": True,
            "track_inventory": True,
        },
    )
    product_id = int(created["id"])
    ctx.record_cleanup("pos_product", lambda: ctx.client.request("DELETE", f"/pos-products/{product_id}"))
    assert_true(
        ctx,
        "create:pos_product",
        str(created.get("name")).startswith("Coolant Smoke"),
        "POS product should be created.",
    )
    updated = ctx.client.put(
        f"/pos-products/{product_id}",
        {
            "buying_price": 950,
            "price": 1250,
            "stock_quantity": 18,
            "is_active": True,
        },
    )
    assert_true(
        ctx,
        "update:pos_product",
        float(updated.get("buying_price") or 0) == 950,
        "Buying price should update to 950.",
    )


def smoke_invoice_and_templates(ctx: SmokeContext, suffix: str) -> None:
    existing = ctx.client.get(f"/invoice-profiles/{ctx.station_id}")
    original_prefix = existing.get("invoice_prefix")
    original_notes = existing.get("sale_invoice_notes")
    updated = ctx.client.put(
        f"/invoice-profiles/{ctx.station_id}",
        {
            "business_name": existing.get("business_name"),
            "legal_name": existing.get("legal_name"),
            "registration_no": existing.get("registration_no"),
            "tax_registration_no": existing.get("tax_registration_no"),
            "default_tax_rate": existing.get("default_tax_rate", 0),
            "tax_inclusive": existing.get("tax_inclusive", False),
            "region_code": existing.get("region_code"),
            "currency_code": existing.get("currency_code"),
            "compliance_mode": existing.get("compliance_mode"),
            "enforce_tax_registration": existing.get("enforce_tax_registration", False),
            "invoice_prefix": f"SA{suffix[-3:]}",
            "invoice_series": existing.get("invoice_series"),
            "invoice_number_width": existing.get("invoice_number_width", 5),
            "payment_terms": existing.get("payment_terms"),
            "footer_text": existing.get("footer_text"),
            "sale_invoice_notes": f"station admin smoke {suffix}",
        },
    )
    assert_true(
        ctx,
        "update:invoice_profile",
        str(updated.get("invoice_prefix")) == f"SA{suffix[-3:]}",
        "Invoice prefix should update.",
    )
    ctx.record_cleanup(
        "invoice_profile",
        lambda: ctx.client.put(
            f"/invoice-profiles/{ctx.station_id}",
            {
                "business_name": existing.get("business_name"),
                "legal_name": existing.get("legal_name"),
                "registration_no": existing.get("registration_no"),
                "tax_registration_no": existing.get("tax_registration_no"),
                "default_tax_rate": existing.get("default_tax_rate", 0),
                "tax_inclusive": existing.get("tax_inclusive", False),
                "region_code": existing.get("region_code"),
                "currency_code": existing.get("currency_code"),
                "compliance_mode": existing.get("compliance_mode"),
                "enforce_tax_registration": existing.get("enforce_tax_registration", False),
                "invoice_prefix": original_prefix,
                "invoice_series": existing.get("invoice_series"),
                "invoice_number_width": existing.get("invoice_number_width", 5),
                "payment_terms": existing.get("payment_terms"),
                "footer_text": existing.get("footer_text"),
                "sale_invoice_notes": original_notes,
            },
        ),
    )

    template = ctx.client.get(f"/document-templates/{ctx.station_id}/fuel_sale_invoice")
    original_name = template.get("name")
    updated_template = ctx.client.put(
        f"/document-templates/{ctx.station_id}/fuel_sale_invoice",
        {
            "name": f"Fuel Sale Invoice Smoke {suffix}",
            "header_html": template.get("header_html"),
            "body_html": template.get("body_html"),
            "footer_html": template.get("footer_html"),
            "is_active": bool(template.get("is_active", True)),
        },
    )
    assert_true(
        ctx,
        "update:document_template",
        str(updated_template.get("name")).startswith("Fuel Sale Invoice Smoke"),
        "Document template name should update.",
    )
    ctx.record_cleanup(
        "document_template",
        lambda: ctx.client.put(
            f"/document-templates/{ctx.station_id}/fuel_sale_invoice",
            {
                "name": original_name,
                "header_html": template.get("header_html"),
                "body_html": template.get("body_html"),
                "footer_html": template.get("footer_html"),
                "is_active": bool(template.get("is_active", True)),
            },
        ),
    )


def smoke_price_and_meter_history(ctx: SmokeContext, suffix: str) -> None:
    fuel_history = ctx.client.get(
        "/fuel-types/1/price-history",
        query={"station_id": ctx.station_id, "limit": 1},
    )
    current_price = float(fuel_history[0]["price"]) if fuel_history else 100.0
    entry = ctx.client.post(
        "/fuel-types/1/price-history",
        {
            "station_id": ctx.station_id,
            "price": current_price,
            "reason": f"station admin smoke {suffix}",
            "notes": "same-price history smoke entry",
        },
    )
    assert_true(
        ctx,
        "create:fuel_price_history",
        abs(float(entry.get("price") or 0) - current_price) < 0.0001,
        "Fuel price history should be recorded at the current price.",
    )

    nozzles = ctx.client.get("/nozzles/", query={"station_id": ctx.station_id})
    nozzle = first(nozzles, lambda item: int(item.get("id", 0)) == 1)
    reading = float(nozzle["meter_reading"])
    bumped_reading = reading + 1
    adjustment = ctx.client.post(
        "/nozzles/1/adjust-meter",
        {
            "old_reading": reading,
            "new_reading": bumped_reading,
            "reason": f"station admin smoke {suffix}",
        },
    )
    assert_true(
        ctx,
        "create:meter_adjustment",
        float(adjustment.get("new_reading") or -1) == bumped_reading,
        "Meter adjustment should be recorded at the bumped reading.",
    )
    ctx.record_cleanup(
        "meter_adjustment_restore",
        lambda: ctx.client.post(
            "/nozzles/1/adjust-meter",
            {
                "old_reading": bumped_reading,
                "new_reading": reading,
                "reason": f"station admin smoke restore {suffix}",
            },
        ),
    )


def smoke_tanker_flow(ctx: SmokeContext, suffix: str) -> None:
    tankers = ctx.client.get("/tankers/", query={"station_id": ctx.station_id})
    suppliers = ctx.client.get("/suppliers/")
    tanks = ctx.client.get("/tanks/", query={"station_id": ctx.station_id})
    customers = ctx.client.get("/customers/", query={"station_id": ctx.station_id, "limit": 200})
    tanker = first(tankers, lambda item: str(item.get("status")) == "active")
    supplier = first(suppliers, lambda item: str(item.get("code")) == "SUP-PSO")
    tank = first(tanks, lambda item: str(item.get("code")) == "HQ-T1")
    customer = first(customers, lambda item: str(item.get("code")) == "TANKER-CUST")
    load_fuel_type_id = int(tank["fuel_type_id"])
    compartments = ctx.client.get(f"/tankers/{tanker['id']}/compartments")
    compartment = compartments[0]

    trip = ctx.client.post(
        "/tankers/trips",
        {
            "tanker_id": tanker["id"],
            "station_id": ctx.station_id,
            "supplier_id": supplier["id"],
            "fuel_type_id": load_fuel_type_id,
            "trip_type": "mixed_delivery",
            "destination_name": f"Smoke Route {suffix}",
            "notes": f"station admin smoke {suffix}",
            "compartment_loads": [
                {
                    "compartment_id": compartment["id"],
                    "fuel_type_id": load_fuel_type_id,
                    "loaded_quantity": 10,
                    "purchase_rate": 100,
                }
            ],
        },
    )
    trip_id = int(trip["id"])
    assert_true(ctx, "create:tanker_trip", trip_id > 0, "Tanker trip should be created.")
    load_id = int(trip["compartment_loads"][0]["id"])
    delivery_trip = ctx.client.post(
        f"/tankers/trips/{trip_id}/deliveries",
        {
            "customer_id": customer["id"],
            "fuel_type_id": load_fuel_type_id,
            "compartment_load_id": load_id,
            "destination_name": f"Smoke Pump {suffix}",
            "quantity": 4,
            "fuel_rate": 260,
            "sale_type": "credit",
            "paid_amount": 0,
        },
    )
    delivery = delivery_trip["deliveries"][0]
    assert_true(
        ctx,
        "create:tanker_delivery",
        float(delivery.get("outstanding_amount") or 0) == 1040,
        "Tanker delivery outstanding should be 1040.",
    )
    payment_trip = ctx.client.post(
        f"/tankers/trips/{trip_id}/deliveries/{delivery['id']}/payments",
        {
            "amount": 240,
            "payment_method": "cash",
            "reference_no": f"SA-SMOKE-{suffix}",
        },
    )
    updated_delivery = first(
        payment_trip["deliveries"],
        lambda item: int(item["id"]) == int(delivery["id"]),
    )
    assert_true(
        ctx,
        "create:tanker_payment",
        float(updated_delivery.get("outstanding_amount") or 0) == 800,
        "Outstanding after tanker payment should be 800.",
    )
    expense_trip = ctx.client.post(
        f"/tankers/trips/{trip_id}/expenses",
        {"expense_type": "Route", "amount": 50, "notes": f"station admin smoke {suffix}"},
    )
    assert_true(
        ctx,
        "create:tanker_expense",
        len(expense_trip.get("expenses") or []) >= 1,
        "Tanker trip should contain the new expense.",
    )
    completed_trip = ctx.client.post(
        f"/tankers/trips/{trip_id}/complete",
        {
            "reason": f"station admin smoke {suffix}",
            "transfer_to_tank_id": tank["id"],
            "transfer_quantity": 6,
        },
    )
    assert_true(
        ctx,
        "complete:tanker_trip",
        str(completed_trip.get("status")) in {"settled", "partially_settled", "completed"},
        "Tanker trip should close successfully.",
    )


def write_report(path: Path, results: list[SmokeResult]) -> None:
    payload = {
        "generated_at_epoch": int(time.time()),
        "results": [
            {"name": item.name, "passed": item.passed, "details": item.details}
            for item in results
        ],
    }
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> None:
    args = parse_args()
    client = ApiClient(args.base_url).login(args.username, args.password)
    station_id, organization_id = get_station_context(client)
    ctx = SmokeContext(client=client, station_id=station_id, organization_id=organization_id)
    suffix = _now_suffix()

    failure: Exception | None = None
    try:
        smoke_auth_and_reads(ctx)
        smoke_user_and_profile_crud(ctx, suffix)
        smoke_supplier_crud(ctx, suffix)
        smoke_inventory_crud(ctx, suffix)
        smoke_invoice_and_templates(ctx, suffix)
        smoke_price_and_meter_history(ctx, suffix)
        if args.include_tanker:
            smoke_tanker_flow(ctx, suffix)
    except Exception as exc:  # noqa: BLE001
        failure = exc
        ctx.fail("runtime", str(exc))
    finally:
        ctx.run_cleanup()
        write_report(Path(args.write_report), ctx.report)

    failed = [item for item in ctx.report if not item.passed]
    for item in ctx.report:
        marker = "OK" if item.passed else "FAIL"
        print(f"[{marker}] {item.name}: {item.details}")
    if failed or failure is not None:
        raise SystemExit(1)
    print(
        "STATION_ADMIN_SMOKE_OK "
        f"({len(ctx.report)} checks, tanker={'on' if args.include_tanker else 'off'}, "
        f"report={args.write_report})"
    )


if __name__ == "__main__":
    main()
