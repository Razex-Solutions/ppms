from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.organization_module_setting import OrganizationModuleSetting
from app.models.user import User
from app.schemas.organization_module_setting import (
    OrganizationModuleSettingResponse,
    OrganizationModuleSettingUpdate,
)
from app.services.audit import log_audit_event
from app.services.organization_modules import ensure_organization_module_access, set_organization_module


router = APIRouter(prefix="/organization-modules", tags=["Organization Modules"])


@router.get("/{organization_id}", response_model=list[OrganizationModuleSettingResponse])
def list_organization_modules(
    organization_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "organization_modules", "read", detail="You do not have permission to view organization modules")
    ensure_organization_module_access(db, organization_id, current_user)
    return (
        db.query(OrganizationModuleSetting)
        .filter(OrganizationModuleSetting.organization_id == organization_id)
        .all()
    )


@router.put("/{organization_id}", response_model=OrganizationModuleSettingResponse)
def update_organization_module(
    organization_id: int,
    data: OrganizationModuleSettingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "organization_modules", "update", detail="You do not have permission to update organization modules")
    ensure_organization_module_access(db, organization_id, current_user)
    setting = set_organization_module(db, organization_id, data.module_name, data.is_enabled)
    log_audit_event(
        db,
        current_user=current_user,
        module="organization_modules",
        action="organization_modules.update",
        entity_type="organization_module_setting",
        entity_id=setting.id,
        details={"organization_id": organization_id, "module_name": data.module_name, "is_enabled": data.is_enabled},
    )
    db.commit()
    db.refresh(setting)
    return setting
