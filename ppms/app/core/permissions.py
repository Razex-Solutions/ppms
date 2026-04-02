from fastapi import HTTPException

from app.models.user import User


PERMISSION_MATRIX: dict[str, dict[str, set[str]]] = {
    "audit_logs": {
        "read": {"Admin", "Manager", "Accountant"},
    },
    "reports": {
        "read": {"Admin", "Manager", "Accountant"},
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
