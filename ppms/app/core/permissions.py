from fastapi import HTTPException

from app.models.user import User


CORE_ROLE_NAMES = {"MasterAdmin", "Admin", "StationAdmin", "HeadOffice", "Manager", "Operator", "Accountant"}

ROLE_SCOPE_RULES: dict[str, dict[str, object]] = {
    "MasterAdmin": {
        "scope_level": "platform",
        "requires_organization": False,
        "requires_station": False,
        "platform_only": True,
    },
    "HeadOffice": {
        "scope_level": "organization",
        "requires_organization": True,
        "requires_station": False,
        "platform_only": False,
    },
    "Admin": {
        "scope_level": "organization",
        "requires_organization": True,
        "requires_station": False,
        "platform_only": False,
    },
    "StationAdmin": {
        "scope_level": "station",
        "requires_organization": True,
        "requires_station": True,
        "platform_only": False,
    },
    "Manager": {
        "scope_level": "station",
        "requires_organization": True,
        "requires_station": True,
        "platform_only": False,
    },
    "Accountant": {
        "scope_level": "station",
        "requires_organization": True,
        "requires_station": True,
        "platform_only": False,
    },
    "Operator": {
        "scope_level": "station",
        "requires_organization": True,
        "requires_station": True,
        "platform_only": False,
    },
}

ROLE_CREATION_RULES: dict[str, set[str]] = {
    "MasterAdmin": {"MasterAdmin", "HeadOffice", "Admin", "StationAdmin", "Manager", "Accountant", "Operator"},
    "HeadOffice": {"Admin", "StationAdmin", "Manager", "Accountant", "Operator"},
    "Admin": {"StationAdmin", "Manager", "Accountant", "Operator"},
    "StationAdmin": {"Manager", "Accountant", "Operator"},
    "Manager": {"Operator"},
}

ROLE_CAPABILITY_SUMMARY: dict[str, dict[str, str]] = {
    "MasterAdmin": {
        "scope": "Platform-wide",
        "governance": "Razex Solutions platform control, tenant onboarding, subscription control, and full support authority",
        "operations": "Can inspect and override any tenant configuration or operational module when needed",
    },
    "Admin": {
        "scope": "System-wide",
        "governance": "Full system control, configuration, security, and maintenance",
        "operations": "All operational modules",
    },
    "StationAdmin": {
        "scope": "Station-wide",
        "governance": "Station administration, user management, setup, and delegated control from the organization",
        "operations": "Most station modules with limited cross-organization authority",
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
    "employee_profiles": {
        "create": {"MasterAdmin", "Admin", "HeadOffice", "StationAdmin", "Manager"},
        "update": {"MasterAdmin", "Admin", "HeadOffice", "StationAdmin", "Manager"},
        "delete": {"MasterAdmin", "Admin", "HeadOffice", "StationAdmin"},
        "read": {"MasterAdmin", "Admin", "HeadOffice", "StationAdmin", "Manager", "Accountant"},
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
    if role_name == "MasterAdmin":
        return {
            module: sorted(actions.keys())
            for module, actions in PERMISSION_MATRIX.items()
        }
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
        "role_scope_rules": ROLE_SCOPE_RULES,
        "role_creation_rules": {role: sorted(targets) for role, targets in ROLE_CREATION_RULES.items()},
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


def get_creatable_roles(role_name: str) -> list[str]:
    return sorted(ROLE_CREATION_RULES.get(role_name, set()))


def ensure_role_creation_allowed(current_user: User, target_role_name: str) -> None:
    if current_user.role.name == "MasterAdmin" or getattr(current_user, "is_platform_user", False):
        return
    allowed_targets = ROLE_CREATION_RULES.get(current_user.role.name, set())
    if target_role_name not in allowed_targets:
        raise HTTPException(
            status_code=403,
            detail=f"You are not allowed to create users with the role '{target_role_name}'",
        )


def get_role_scope_rule(role_name: str) -> dict[str, object]:
    return ROLE_SCOPE_RULES.get(
        role_name,
        {
            "scope_level": "station",
            "requires_organization": True,
            "requires_station": True,
            "platform_only": False,
        },
    )


def require_permission(current_user: User, module: str, action: str, detail: str | None = None) -> None:
    allowed_roles = PERMISSION_MATRIX.get(module, {}).get(action)
    if not allowed_roles:
        raise HTTPException(status_code=403, detail=detail or "Action is not permitted")

    if current_user.role.name == "MasterAdmin" or getattr(current_user, "is_platform_user", False):
        return

    if current_user.role.name not in allowed_roles:
        raise HTTPException(status_code=403, detail=detail or "You do not have permission for this action")
