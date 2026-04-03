from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class NavigationItem:
    key: str
    title: str
    view_name: str
    required_module: str | None = None
    required_permission: tuple[str, str] | None = None


NAVIGATION_ITEMS = [
    NavigationItem("dashboard", "Dashboard", "dashboard"),
    NavigationItem("sales", "Sales", "sales", required_module="fuel_sales", required_permission=("fuel_sales", "create")),
    NavigationItem("inventory", "Inventory", "inventory", required_module="tanks"),
    NavigationItem("reports", "Reports", "reports", required_module="reports", required_permission=("reports", "read")),
    NavigationItem("attendance", "Attendance", "attendance", required_module="attendance", required_permission=("attendance", "read")),
    NavigationItem("payroll", "Payroll", "payroll", required_module="payroll", required_permission=("payroll", "read")),
    NavigationItem("notifications", "Notifications", "notifications", required_module="notifications", required_permission=("notifications", "read")),
    NavigationItem("sessions", "Sessions", "sessions"),
    NavigationItem("settings", "Settings", "settings"),
]


def build_navigation(enabled_modules: list[str], permissions: dict[str, list[str]]) -> list[NavigationItem]:
    enabled = set(enabled_modules)
    visible: list[NavigationItem] = []
    for item in NAVIGATION_ITEMS:
        if item.required_module and item.required_module not in enabled:
            continue
        if item.required_permission:
            module_name, action = item.required_permission
            if action not in permissions.get(module_name, []):
                continue
        visible.append(item)
    return visible
