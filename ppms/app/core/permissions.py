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
    "station_modules": {
        "read": {"Admin", "HeadOffice"},
        "update": {"Admin", "HeadOffice"},
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
        "approve": {"Admin", "HeadOffice"},
        "reject": {"Admin", "HeadOffice"},
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
