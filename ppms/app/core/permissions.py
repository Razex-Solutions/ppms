from fastapi import HTTPException

from app.models.user import User


CORE_ROLE_NAMES = {"MasterAdmin", "StationAdmin", "HeadOffice", "Manager", "Operator", "Accountant"}

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
    "MasterAdmin": {"MasterAdmin", "HeadOffice", "StationAdmin", "Manager", "Accountant", "Operator"},
    "HeadOffice": {"StationAdmin", "Manager", "Accountant", "Operator"},
    "StationAdmin": {"Manager", "Accountant", "Operator"},
    "Manager": {"Operator"},
}

ROLE_CAPABILITY_SUMMARY: dict[str, dict[str, str]] = {
    "MasterAdmin": {
        "scope": "Platform-wide",
        "governance": "Razex Solutions platform control, tenant onboarding, subscription control, and full support authority",
        "operations": "Can inspect and override any tenant configuration or operational module when needed",
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
        "create": {"HeadOffice", "StationAdmin"},
        "update": {"HeadOffice", "StationAdmin"},
        "delete": {"HeadOffice", "StationAdmin"},
        "read": {"HeadOffice", "StationAdmin"},
    },
    "employee_profiles": {
        "create": {"MasterAdmin", "HeadOffice", "StationAdmin", "Manager"},
        "update": {"MasterAdmin", "HeadOffice", "StationAdmin", "Manager"},
        "delete": {"MasterAdmin", "HeadOffice", "StationAdmin"},
        "read": {"MasterAdmin", "HeadOffice", "StationAdmin", "Manager", "Accountant"},
    },
    "organizations": {
        "create": {"HeadOffice"},
        "update": {"HeadOffice"},
        "delete": {"HeadOffice"},
        "read": {"HeadOffice"},
    },
    "organization_modules": {
        "read": {"HeadOffice"},
        "update": {"HeadOffice"},
    },
    "online_api_hooks": {
        "read": {"HeadOffice"},
        "update": {"HeadOffice"},
        "trigger": {"HeadOffice"},
    },
    "roles": {
        "create": {"HeadOffice"},
        "update": {"HeadOffice"},
        "delete": {"HeadOffice"},
        "read": {"HeadOffice", "StationAdmin"},
    },
    "stations": {
        "create": {"HeadOffice"},
        "update": {"HeadOffice"},
        "delete": {"HeadOffice"},
        "read": {"HeadOffice"},
    },
    "station_modules": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Operator", "Accountant"},
        "update": {"HeadOffice", "StationAdmin"},
    },
    "invoice_profiles": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
        "update": {"HeadOffice", "StationAdmin", "Manager"},
    },
    "document_templates": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
        "update": {"HeadOffice", "StationAdmin", "Manager"},
    },
    "maintenance": {
        "read": {"MasterAdmin", "HeadOffice"},
        "execute": {"MasterAdmin", "HeadOffice"},
    },
    "saas": {
        "read": {"HeadOffice"},
        "manage": {"HeadOffice"},
    },
    "fuel_types": {
        "create": {"HeadOffice", "StationAdmin"},
        "update": {"HeadOffice", "StationAdmin"},
        "delete": {"HeadOffice", "StationAdmin"},
    },
    "fuel_pricing": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Operator", "Accountant"},
        "update": {"HeadOffice", "StationAdmin", "Manager"},
    },
    "tanks": {
        "create": {"StationAdmin", "Manager"},
        "update": {"StationAdmin", "Manager"},
        "delete": {"StationAdmin", "Manager"},
    },
    "dispensers": {
        "create": {"StationAdmin", "Manager"},
        "update": {"StationAdmin", "Manager"},
        "delete": {"StationAdmin", "Manager"},
    },
    "nozzles": {
        "create": {"StationAdmin", "Manager"},
        "update": {"StationAdmin", "Manager"},
        "delete": {"StationAdmin", "Manager"},
        "adjust_meter": {"HeadOffice", "StationAdmin"},
        "read_meter_history": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
    },
    "tankers": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Operator", "Accountant"},
        "create": {"StationAdmin", "Manager"},
        "update": {"StationAdmin", "Manager"},
        "delete": {"StationAdmin", "Manager"},
        "trip_create": {"StationAdmin", "Manager", "Operator"},
        "delivery_create": {"StationAdmin", "Manager", "Operator"},
        "expense_create": {"StationAdmin", "Manager", "Operator", "Accountant"},
        "complete": {"StationAdmin", "Manager", "Operator"},
    },
    "customers": {
        "create": {"StationAdmin", "Manager", "Accountant"},
        "update": {"StationAdmin", "Manager", "Accountant"},
        "delete": {"StationAdmin", "Manager"},
        "request_credit_override": {"StationAdmin", "Manager", "Accountant"},
        "approve_credit_override": {"HeadOffice", "StationAdmin"},
        "reject_credit_override": {"HeadOffice", "StationAdmin"},
    },
    "suppliers": {
        "create": {"StationAdmin", "Manager", "Accountant"},
        "update": {"StationAdmin", "Manager", "Accountant"},
        "delete": {"StationAdmin", "Manager"},
    },
    "fuel_sales": {
        "create": {"StationAdmin", "Manager", "Operator"},
        "reverse": {"StationAdmin", "Manager", "Operator"},
        "approve_reverse": {"HeadOffice", "StationAdmin"},
        "reject_reverse": {"HeadOffice", "StationAdmin"},
    },
    "purchases": {
        "create": {"StationAdmin", "Manager", "Operator"},
        "approve": {"HeadOffice", "StationAdmin"},
        "reject": {"HeadOffice", "StationAdmin"},
        "reverse": {"StationAdmin", "Manager", "Operator"},
        "approve_reverse": {"HeadOffice", "StationAdmin"},
        "reject_reverse": {"HeadOffice", "StationAdmin"},
    },
    "internal_fuel_usage": {
        "create": {"StationAdmin", "Manager", "Operator"},
        "read": {"HeadOffice", "StationAdmin", "Manager", "Operator", "Accountant"},
    },
    "customer_payments": {
        "create": {"StationAdmin", "Manager", "Operator", "Accountant"},
        "reverse": {"StationAdmin", "Manager", "Operator", "Accountant"},
        "approve_reverse": {"HeadOffice", "StationAdmin"},
        "reject_reverse": {"HeadOffice", "StationAdmin"},
    },
    "supplier_payments": {
        "create": {"StationAdmin", "Manager", "Operator", "Accountant"},
        "reverse": {"StationAdmin", "Manager", "Operator", "Accountant"},
        "approve_reverse": {"HeadOffice", "StationAdmin"},
        "reject_reverse": {"HeadOffice", "StationAdmin"},
    },
    "ledger": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
    },
    "shifts": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Operator", "Accountant"},
        "open": {"StationAdmin", "Manager", "Operator"},
        "close": {"StationAdmin", "Manager", "Operator"},
        "submit_cash": {"StationAdmin", "Manager", "Operator"},
    },
    "attendance": {
        "check_in": {"StationAdmin", "Manager", "Operator", "Accountant"},
        "check_out": {"StationAdmin", "Manager", "Operator", "Accountant"},
        "create": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
        "update": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
        "read": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
    },
    "payroll": {
        "create": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
        "finalize": {"HeadOffice", "StationAdmin", "Accountant"},
        "read": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
    },
    "tank_dips": {
        "create": {"StationAdmin", "Manager", "Operator"},
    },
    "pos_products": {
        "create": {"StationAdmin", "Manager"},
        "update": {"StationAdmin", "Manager"},
        "delete": {"StationAdmin", "Manager"},
    },
    "pos_sales": {
        "create": {"StationAdmin", "Manager", "Operator"},
        "reverse": {"StationAdmin", "Manager", "Operator"},
    },
    "audit_logs": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
    },
    "notifications": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Operator", "Accountant"},
    },
    "delivery_jobs": {
        "process": {"HeadOffice", "StationAdmin"},
    },
    "reports": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Accountant"},
    },
    "expenses": {
        "create": {"StationAdmin", "Manager", "Accountant"},
        "update": {"StationAdmin", "Manager", "Accountant"},
        "delete": {"StationAdmin", "Manager", "Accountant"},
        "approve": {"HeadOffice", "StationAdmin"},
        "reject": {"HeadOffice", "StationAdmin"},
    },
    "hardware": {
        "read": {"HeadOffice", "StationAdmin", "Manager", "Operator", "Accountant"},
        "create": {"StationAdmin", "Manager"},
        "update": {"StationAdmin", "Manager"},
        "delete": {"StationAdmin", "Manager"},
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
