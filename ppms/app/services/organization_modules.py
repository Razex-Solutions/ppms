from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.models.organization import Organization
from app.models.organization_module_setting import OrganizationModuleSetting
from app.models.user import User


def ensure_organization_module_access(db: Session, organization_id: int, current_user: User) -> Organization:
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return organization
    if is_head_office_user(current_user) and get_user_organization_id(current_user) == organization_id:
        return organization
    raise HTTPException(status_code=403, detail="Not authorized for this organization")


def is_organization_module_enabled(db: Session, organization_id: int, module_name: str) -> bool:
    setting = (
        db.query(OrganizationModuleSetting)
        .filter(
            OrganizationModuleSetting.organization_id == organization_id,
            OrganizationModuleSetting.module_name == module_name,
        )
        .first()
    )
    return bool(setting and setting.is_enabled)


def set_organization_module(db: Session, organization_id: int, module_name: str, is_enabled: bool) -> OrganizationModuleSetting:
    setting = (
        db.query(OrganizationModuleSetting)
        .filter(
            OrganizationModuleSetting.organization_id == organization_id,
            OrganizationModuleSetting.module_name == module_name,
        )
        .first()
    )
    if setting is None:
        setting = OrganizationModuleSetting(
            organization_id=organization_id,
            module_name=module_name,
            is_enabled=is_enabled,
        )
        db.add(setting)
    else:
        setting.is_enabled = is_enabled
    db.commit()
    db.refresh(setting)
    return setting
