import json

from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog
from app.models.user import User


def log_audit_event(
    db: Session,
    *,
    current_user: User | None,
    module: str,
    action: str,
    entity_type: str,
    entity_id: int | None = None,
    station_id: int | None = None,
    details: dict | None = None,
) -> AuditLog:
    log = AuditLog(
        user_id=current_user.id if current_user else None,
        username=current_user.username if current_user else None,
        station_id=station_id if station_id is not None else getattr(current_user, "station_id", None),
        module=module,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        details_json=json.dumps(details, sort_keys=True) if details else None,
    )
    db.add(log)
    return log
