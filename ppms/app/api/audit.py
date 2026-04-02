from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.audit_log import AuditLog
from app.models.user import User
from app.schemas.audit import AuditLogResponse

router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])


@router.get("/", response_model=list[AuditLogResponse])
def list_audit_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    module: str | None = Query(None),
    action: str | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "audit_logs", "read", detail="You do not have permission to view audit logs")
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    query = db.query(AuditLog)
    if station_id is not None:
        query = query.filter(AuditLog.station_id == station_id)
    if module:
        query = query.filter(AuditLog.module == module)
    if action:
        query = query.filter(AuditLog.action == action)
    if from_date:
        query = query.filter(AuditLog.created_at >= from_date)
    if to_date:
        query = query.filter(AuditLog.created_at < to_date)
    return query.order_by(AuditLog.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{audit_log_id}", response_model=AuditLogResponse)
def get_audit_log(
    audit_log_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "audit_logs", "read", detail="You do not have permission to view audit logs")
    audit_log = db.query(AuditLog).filter(AuditLog.id == audit_log_id).first()
    if not audit_log:
        raise HTTPException(status_code=404, detail="Audit log not found")
    if current_user.role.name != "Admin" and audit_log.station_id != current_user.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this audit log")
    return audit_log
