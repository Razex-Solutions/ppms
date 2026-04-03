import shutil
import sqlite3
from datetime import datetime
from pathlib import Path

from fastapi import HTTPException

from app.core.config import (
    APP_ENV,
    BACKUP_DIRECTORY,
    BACKUP_RETENTION_COUNT,
    DATABASE_URL,
    DELIVERY_WORKER_ENABLED,
)
from app.core.time import utc_now


def _ensure_sqlite_database() -> Path:
    if not DATABASE_URL.startswith("sqlite:///"):
        raise HTTPException(status_code=400, detail="Maintenance helpers currently support SQLite deployments only")
    source_path = Path(DATABASE_URL.replace("sqlite:///", "", 1)).resolve()
    if not source_path.exists():
        raise HTTPException(status_code=404, detail="Database file not found")
    return source_path


def _resolve_backup_dir() -> Path:
    backup_dir = Path(BACKUP_DIRECTORY).resolve()
    backup_dir.mkdir(parents=True, exist_ok=True)
    return backup_dir


def _build_backup_item(path: Path) -> dict:
    return {
        "name": path.name,
        "path": str(path),
        "size_bytes": path.stat().st_size,
        "modified_at": datetime.fromtimestamp(path.stat().st_mtime).isoformat(),
    }


def _prune_old_backups(backup_dir: Path) -> int:
    if BACKUP_RETENTION_COUNT <= 0:
        return 0
    files = [path for path in sorted(backup_dir.glob("*"), reverse=True) if path.is_file()]
    removed = 0
    for path in files[BACKUP_RETENTION_COUNT:]:
        path.unlink(missing_ok=True)
        removed += 1
    return removed


def run_database_integrity_check() -> dict:
    db_path = _ensure_sqlite_database()
    connection = sqlite3.connect(db_path)
    try:
        result = connection.execute("PRAGMA integrity_check;").fetchone()
    finally:
        connection.close()
    status = "ok" if result and result[0] == "ok" else "failed"
    return {
        "status": status,
        "database_path": str(db_path),
        "detail": result[0] if result else "No integrity result returned",
        "checked_at": utc_now().isoformat(),
    }


def get_system_snapshot() -> dict:
    db_path = _ensure_sqlite_database()
    backup_dir = _resolve_backup_dir()
    backups = [path for path in sorted(backup_dir.glob("*"), reverse=True) if path.is_file()]
    latest_backup = _build_backup_item(backups[0]) if backups else None
    integrity = run_database_integrity_check()
    return {
        "environment": APP_ENV,
        "database_url": DATABASE_URL,
        "database_path": str(db_path),
        "database_exists": db_path.exists(),
        "database_size_bytes": db_path.stat().st_size if db_path.exists() else 0,
        "delivery_worker_enabled": DELIVERY_WORKER_ENABLED,
        "backup_directory": str(backup_dir),
        "backup_retention_count": BACKUP_RETENTION_COUNT,
        "backup_count": len(backups),
        "latest_backup": latest_backup,
        "database_integrity": integrity,
        "captured_at": utc_now().isoformat(),
    }


def create_local_backup() -> dict:
    source_path = _ensure_sqlite_database()
    backup_dir = _resolve_backup_dir()
    timestamp = utc_now().strftime("%Y%m%d%H%M%S")
    backup_path = backup_dir / f"{source_path.stem}_{timestamp}{source_path.suffix}"
    shutil.copy2(source_path, backup_path)
    removed_count = _prune_old_backups(backup_dir)
    return {
        "backup_path": str(backup_path),
        "created_at": utc_now().isoformat(),
        "retention_pruned": removed_count,
    }


def list_local_backups() -> dict:
    backup_dir = _resolve_backup_dir()
    items = [_build_backup_item(path) for path in sorted(backup_dir.glob("*"), reverse=True) if path.is_file()]
    return {"items": items}


def restore_local_backup(backup_name: str) -> dict:
    source_path = _ensure_sqlite_database()
    backup_dir = _resolve_backup_dir()
    backup_path = (backup_dir / backup_name).resolve()
    if backup_path.parent != backup_dir or not backup_path.exists() or not backup_path.is_file():
        raise HTTPException(status_code=404, detail="Backup file not found")

    restored_backup_path = source_path.with_suffix(f"{source_path.suffix}.pre_restore")
    shutil.copy2(source_path, restored_backup_path)
    shutil.copy2(backup_path, source_path)
    integrity = run_database_integrity_check()
    if integrity["status"] != "ok":
        shutil.copy2(restored_backup_path, source_path)
        raise HTTPException(status_code=500, detail="Restore failed integrity check and was rolled back")

    return {
        "restored_from": backup_name,
        "database_path": str(source_path),
        "safety_backup_path": str(restored_backup_path),
        "restored_at": utc_now().isoformat(),
    }
