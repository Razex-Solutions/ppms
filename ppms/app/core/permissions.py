from fastapi import HTTPException

from app.models.user import User


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
    "roles": {
        "create": {"Admin"},
        "update": {"Admin"},
        "delete": {"Admin"},
    },
    "stations": {
        "create": {"Admin"},
        "update": {"Admin"},
        "delete": {"Admin"},
        "read": {"Admin", "HeadOffice"},
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
    },
    "tankers": {
        "create": {"Admin", "Manager"},
        "update": {"Admin", "Manager"},
        "delete": {"Admin", "Manager"},
    },
    "customers": {
        "create": {"Admin", "Manager", "Accountant"},
        "update": {"Admin", "Manager", "Accountant"},
        "delete": {"Admin", "Manager"},
    },
    "suppliers": {
        "create": {"Admin", "Manager", "Accountant"},
        "update": {"Admin", "Manager", "Accountant"},
        "delete": {"Admin", "Manager"},
    },
    "fuel_sales": {
        "create": {"Admin", "Manager", "Operator"},
        "reverse": {"Admin", "Manager", "Operator"},
    },
    "purchases": {
        "create": {"Admin", "Manager", "Operator"},
        "reverse": {"Admin", "Manager", "Operator"},
    },
    "customer_payments": {
        "create": {"Admin", "Manager", "Operator", "Accountant"},
        "reverse": {"Admin", "Manager", "Operator", "Accountant"},
    },
    "supplier_payments": {
        "create": {"Admin", "Manager", "Operator", "Accountant"},
        "reverse": {"Admin", "Manager", "Operator", "Accountant"},
    },
    "shifts": {
        "open": {"Admin", "Manager", "Operator"},
        "close": {"Admin", "Manager", "Operator"},
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
    "reports": {
        "read": {"Admin", "HeadOffice", "Manager", "Accountant"},
    },
    "expenses": {
        "create": {"Admin", "Manager", "Accountant"},
        "update": {"Admin", "Manager", "Accountant"},
        "delete": {"Admin", "Manager", "Accountant"},
    },
    "hardware": {
        "create": {"Admin", "Manager"},
        "update": {"Admin", "Manager"},
        "delete": {"Admin", "Manager"},
    },
}


def require_permission(current_user: User, module: str, action: str, detail: str | None = None) -> None:
    allowed_roles = PERMISSION_MATRIX.get(module, {}).get(action)
    if not allowed_roles:
        raise HTTPException(status_code=403, detail=detail or "Action is not permitted")

    if current_user.role.name not in allowed_roles:
        raise HTTPException(status_code=403, detail=detail or "You do not have permission for this action")
