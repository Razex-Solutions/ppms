from fastapi import HTTPException

from app.models.user import User


CORE_ROLE_NAMES = {"Admin", "HeadOffice", "Manager", "Operator", "Accountant"}

ROLE_CAPABILITY_SUMMARY: dict[str, dict[str, str]] = {
    "Admin": {
        "scope": "System-wide",
        "governance": "Full system control, configuration, security, and maintenance",
        "operations": "All operational modules",
    },
    "HeadOffice": {
        "scope": "Organization-wide",
        "governance": "Approvals, oversight, reporting, and organization controls",
        "operations": "Read-heavy with approval authority across the organization",
    },
    "Manager": {
        "scope": "Station-wide",
        "governance": "Station configuration and supervised operational management",
        "operations": "Most station workflows except sensitive governance actions",
    },
    "Operator": {
        "scope": "Station-wide",
        "governance": "Day-to-day execution without governance authority",
        "operations": "Sales, shifts, purchases, and frontline workflows",
    },
    "Accountant": {
        "scope": "Station-wide",
        "governance": "Financial review with limited operational mutation",
        "operations": "Payments, ledgers, documents, and reporting",
    },
}


PERMISSION_MATRIX: dict[str, dict[str, set[str]]] = {
    "users": {
        "create": {"Admin"},
        "update": {"Admin"},
        "delete": {"Admin"},
        "read": {"Admin", "HeadOffice"},
    },
    "organizations": {
        "create": {"Admin"},
        "update": {"Admin"},
        "delete": {"Admin"},
        "read": {"Admin", "HeadOffice"},
    },
    "organization_modules": {
        "read": {"Admin", "HeadOffice"},
        "update": {"Admin", "HeadOffice"},
    },
    "online_api_hooks": {
        "read": {"Admin", "HeadOffice"},
        "update": {"Admin", "HeadOffice"},
        "trigger": {"Admin", "HeadOffice"},
    },
    "roles": {
        "create": {"Admin"},
        "update": {"Admin"},
        "delete": {"Admin"},
        "read": {"Admin", "HeadOffice"},
    },
    "stations": {
        "create": {"Admin"},
        "update": {"Admin"},
        "delete": {"Admin"},
        "read": {"Admin", "HeadOffice"},
    },
    "station_modules": {
        "read": {"Admin", "HeadOffice"},
        "update": {"Admin", "HeadOffice"},
    },
    "invoice_profiles": {
        "read": {"Admin", "HeadOffice", "Manager", "Accountant"},
        "update": {"Admin", "HeadOffice", "Manager"},
    },
    "document_templates": {
        "read": {"Admin", "HeadOffice", "Manager", "Accountant"},
        "update": {"Admin", "HeadOffice", "Manager"},
    },
    "maintenance": {
        "read": {"Admin"},
        "execute": {"Admin"},
    },
    "saas": {
        "read": {"Admin", "HeadOffice"},
        "manage": {"Admin"},
    },
    "fuel_types": {
        "create": {"Admin"},
        "update": {"Admin"},
        "delete": {"Admin"},
    },
    "tanks": {
        "create": {"Admin", "Manager"},
        "update": {"Admin", "Manager"},
        "delete": {"Admin", "Manager"},
    },
    "dispensers": {
        "create": {"Admin", "Manager"},
        "update": {"Admin", "Manager"},
        "delete": {"Admin", "Manager"},
    },
    "nozzles": {
        "create": {"Admin", "Manager"},
        "update": {"Admin", "Manager"},
        "delete": {"Admin", "Manager"},
        "adjust_meter": {"Admin"},
        "read_meter_history": {"Admin", "HeadOffice", "Manager", "Accountant"},
    },
    "tankers": {
        "read": {"Admin", "HeadOffice", "Manager", "Operator", "Accountant"},
        "create": {"Admin", "Manager"},
        "update": {"Admin", "Manager"},
        "delete": {"Admin", "Manager"},
        "trip_create": {"Admin", "Manager", "Operator"},
        "delivery_create": {"Admin", "Manager", "Operator"},
        "expense_create": {"Admin", "Manager", "Operator", "Accountant"},
        "complete": {"Admin", "Manager", "Operator"},
    },
    "customers": {
        "create": {"Admin", "Manager", "Accountant"},
        "update": {"Admin", "Manager", "Accountant"},
        "delete": {"Admin", "Manager"},
        "request_credit_override": {"Admin", "Manager", "Accountant"},
        "approve_credit_override": {"Admin", "HeadOffice"},
        "reject_credit_override": {"Admin", "HeadOffice"},
    },
    "suppliers": {
        "create": {"Admin", "Manager", "Accountant"},
        "update": {"Admin", "Manager", "Accountant"},
        "delete": {"Admin", "Manager"},
    },
    "fuel_sales": {
        "create": {"Admin", "Manager", "Operator"},
        "reverse": {"Admin", "Manager", "Operator"},
        "approve_reverse": {"Admin", "HeadOffice"},
        "reject_reverse": {"Admin", "HeadOffice"},
    },
    "purchases": {
        "create": {"Admin", "Manager", "Operator"},
        "approve": {"Admin", "HeadOffice"},
        "reject": {"Admin", "HeadOffice"},
        "reverse": {"Admin", "Manager", "Operator"},
        "approve_reverse": {"Admin", "HeadOffice"},
        "reject_reverse": {"Admin", "HeadOffice"},
    },
    "customer_payments": {
        "create": {"Admin", "Manager", "Operator", "Accountant"},
        "reverse": {"Admin", "Manager", "Operator", "Accountant"},
        "approve_reverse": {"Admin", "HeadOffice"},
        "reject_reverse": {"Admin", "HeadOffice"},
    },
    "supplier_payments": {
        "create": {"Admin", "Manager", "Operator", "Accountant"},
        "reverse": {"Admin", "Manager", "Operator", "Accountant"},
        "approve_reverse": {"Admin", "HeadOffice"},
        "reject_reverse": {"Admin", "HeadOffice"},
    },
    "shifts": {
        "open": {"Admin", "Manager", "Operator"},
        "close": {"Admin", "Manager", "Operator"},
    },
    "attendance": {
        "check_in": {"Admin", "Manager", "Operator", "Accountant"},
        "check_out": {"Admin", "Manager", "Operator", "Accountant"},
        "create": {"Admin", "HeadOffice", "Manager", "Accountant"},
        "update": {"Admin", "HeadOffice", "Manager", "Accountant"},
        "read": {"Admin", "HeadOffice", "Manager", "Accountant"},
    },
    "payroll": {
        "create": {"Admin", "HeadOffice", "Manager", "Accountant"},
        "finalize": {"Admin", "HeadOffice", "Accountant"},
        "read": {"Admin", "HeadOffice", "Manager", "Accountant"},
    },
    "tank_dips": {
        "create": {"Admin", "Manager", "Operator"},
    },
    "pos_products": {
        "create": {"Admin", "Manager"},
        "update": {"Admin", "Manager"},
        "delete": {"Admin", "Manager"},
    },
    "pos_sales": {
        "create": {"Admin", "Manager", "Operator"},
        "reverse": {"Admin", "Manager", "Operator"},
    },
    "audit_logs": {
        "read": {"Admin", "HeadOffice", "Manager", "Accountant"},
    },
    "notifications": {
        "read": {"Admin", "HeadOffice", "Manager", "Operator", "Accountant"},
    },
    "delivery_jobs": {
        "process": {"Admin", "HeadOffice"},
    },
    "reports": {
        "read": {"Admin", "HeadOffice", "Manager", "Accountant"},
    },
    "expenses": {
        "create": {"Admin", "Manager", "Accountant"},
        "update": {"Admin", "Manager", "Accountant"},
        "delete": {"Admin", "Manager", "Accountant"},
        "approve": {"Admin", "HeadOffice"},
        "reject": {"Admin", "HeadOffice"},
    },
    "hardware": {
        "read": {"Admin", "HeadOffice", "Manager", "Operator", "Accountant"},
        "create": {"Admin", "Manager"},
        "update": {"Admin", "Manager"},
        "delete": {"Admin", "Manager"},
    },
}


def list_available_modules() -> list[str]:
    return sorted(PERMISSION_MATRIX.keys())


def get_role_permissions(role_name: str) -> dict[str, list[str]]:
    role_permissions: dict[str, list[str]] = {}
    for module, actions in PERMISSION_MATRIX.items():
        allowed_actions = sorted(action for action, roles in actions.items() if role_name in roles)
        if allowed_actions:
            role_permissions[module] = allowed_actions
    return role_permissions


def get_effective_permissions(current_user: User) -> dict[str, list[str]]:
    return get_role_permissions(current_user.role.name)


def get_permission_catalog() -> dict:
    return {
        "core_roles": sorted(CORE_ROLE_NAMES),
        "role_summaries": ROLE_CAPABILITY_SUMMARY,
        "permission_matrix": {
            module: {action: sorted(roles) for action, roles in actions.items()}
            for module, actions in PERMISSION_MATRIX.items()
        },
    }


def is_core_role_name(role_name: str) -> bool:
    return role_name in CORE_ROLE_NAMES


def ensure_core_role_mutation_allowed(role_name: str, action: str) -> None:
    if is_core_role_name(role_name):
        raise HTTPException(status_code=400, detail=f"Core role '{role_name}' cannot be {action}")


def require_permission(current_user: User, module: str, action: str, detail: str | None = None) -> None:
    allowed_roles = PERMISSION_MATRIX.get(module, {}).get(action)
    if not allowed_roles:
        raise HTTPException(status_code=403, detail=detail or "Action is not permitted")

    if current_user.role.name not in allowed_roles:
        raise HTTPException(status_code=403, detail=detail or "You do not have permission for this action")
