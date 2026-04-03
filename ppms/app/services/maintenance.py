import shutil
from datetime import datetime
from pathlib import Path

from fastapi import HTTPException

from app.core.config import APP_ENV, BACKUP_DIRECTORY, DATABASE_URL, DELIVERY_WORKER_ENABLED
from app.core.time import utc_now


def get_system_snapshot() -> dict:
    return {
        "environment": APP_ENV,
        "database_url": DATABASE_URL,
        "delivery_worker_enabled": DELIVERY_WORKER_ENABLED,
        "backup_directory": BACKUP_DIRECTORY,
        "captured_at": utc_now().isoformat(),
    }


def create_local_backup() -> dict:
    if not DATABASE_URL.startswith("sqlite:///"):
        raise HTTPException(status_code=400, detail="Local backup helper currently supports SQLite deployments only")

    source_path = Path(DATABASE_URL.replace("sqlite:///", "", 1)).resolve()
    if not source_path.exists():
        raise HTTPException(status_code=404, detail="Database file not found for backup")

    backup_dir = Path(BACKUP_DIRECTORY).resolve()
    backup_dir.mkdir(parents=True, exist_ok=True)
    timestamp = utc_now().strftime("%Y%m%d%H%M%S")
    backup_path = backup_dir / f"{source_path.stem}_{timestamp}{source_path.suffix}"
    shutil.copy2(source_path, backup_path)
    return {
        "backup_path": str(backup_path),
        "created_at": utc_now().isoformat(),
    }


def list_local_backups() -> dict:
    backup_dir = Path(BACKUP_DIRECTORY).resolve()
    if not backup_dir.exists():
        return {"items": []}
    items = []
    for path in sorted(backup_dir.glob("*"), reverse=True):
        if path.is_file():
            items.append(
                {
                    "name": path.name,
                    "path": str(path),
                    "size_bytes": path.stat().st_size,
                    "modified_at": datetime.fromtimestamp(path.stat().st_mtime).isoformat(),
                }
            )
    return {"items": items}
