from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.user import User
from app.schemas.maintenance import RestoreBackupRequest
from app.services.maintenance import (
    create_local_backup,
    get_system_snapshot,
    list_local_backups,
    restore_local_backup,
    run_database_integrity_check,
)


router = APIRouter(prefix="/maintenance", tags=["Maintenance"])


@router.get("/snapshot")
def get_maintenance_snapshot(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "maintenance", "read", detail="You do not have permission to view maintenance data")
    return get_system_snapshot()


@router.post("/backup")
def trigger_local_backup(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "maintenance", "execute", detail="You do not have permission to run maintenance actions")
    return create_local_backup()


@router.get("/backups")
def get_local_backups(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "maintenance", "read", detail="You do not have permission to view maintenance data")
    return list_local_backups()


@router.get("/integrity")
def get_database_integrity(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "maintenance", "read", detail="You do not have permission to view maintenance data")
    return run_database_integrity_check()


@router.post("/restore")
def restore_backup(
    payload: RestoreBackupRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "maintenance", "execute", detail="You do not have permission to run maintenance actions")
    db.close()
    return restore_local_backup(payload.backup_name)
