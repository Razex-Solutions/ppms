from pydantic import BaseModel


class RestoreBackupRequest(BaseModel):
    backup_name: str
