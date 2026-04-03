from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.online_api_hook import OnlineAPIHook
from app.models.user import User
from app.schemas.online_api_hook import (
    OnlineAPIHookCreate,
    OnlineAPIHookPing,
    OnlineAPIHookResponse,
    OnlineAPIHookUpdate,
)
from app.services.audit import log_audit_event
from app.services.online_api_hooks import (
    create_online_api_hook,
    dispatch_online_api_hook,
    ensure_online_hook_access,
    list_online_api_hooks,
    update_online_api_hook,
)


router = APIRouter(prefix="/online-api-hooks", tags=["Online API Hooks"])


@router.get("/{organization_id}", response_model=list[OnlineAPIHookResponse])
def get_online_api_hooks(
    organization_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "online_api_hooks", "read", detail="You do not have permission to view online API hooks")
    ensure_online_hook_access(db, organization_id, current_user)
    return list_online_api_hooks(db, organization_id)


@router.post("/{organization_id}", response_model=OnlineAPIHookResponse)
def post_online_api_hook(
    organization_id: int,
    data: OnlineAPIHookCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "online_api_hooks", "update", detail="You do not have permission to manage online API hooks")
    ensure_online_hook_access(db, organization_id, current_user)
    hook = create_online_api_hook(db, organization_id, data)
    log_audit_event(
        db,
        current_user=current_user,
        module="online_api_hooks",
        action="online_api_hooks.create",
        entity_type="online_api_hook",
        entity_id=hook.id,
        details={"organization_id": organization_id, "event_type": hook.event_type, "target_url": hook.target_url},
    )
    db.commit()
    db.refresh(hook)
    return hook


@router.put("/item/{hook_id}", response_model=OnlineAPIHookResponse)
def put_online_api_hook(
    hook_id: int,
    data: OnlineAPIHookUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "online_api_hooks", "update", detail="You do not have permission to manage online API hooks")
    hook = db.query(OnlineAPIHook).filter(OnlineAPIHook.id == hook_id).first()
    if not hook:
        raise HTTPException(status_code=404, detail="Online API hook not found")
    ensure_online_hook_access(db, hook.organization_id, current_user)
    hook = update_online_api_hook(db, hook, data)
    log_audit_event(
        db,
        current_user=current_user,
        module="online_api_hooks",
        action="online_api_hooks.update",
        entity_type="online_api_hook",
        entity_id=hook.id,
        details={"organization_id": hook.organization_id, "event_type": hook.event_type, "target_url": hook.target_url},
    )
    db.commit()
    db.refresh(hook)
    return hook


@router.post("/item/{hook_id}/ping")
def ping_online_api_hook(
    hook_id: int,
    data: OnlineAPIHookPing | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "online_api_hooks", "trigger", detail="You do not have permission to trigger online API hooks")
    hook = db.query(OnlineAPIHook).filter(OnlineAPIHook.id == hook_id).first()
    if not hook:
        raise HTTPException(status_code=404, detail="Online API hook not found")
    ensure_online_hook_access(db, hook.organization_id, current_user)
    payload = data.payload if data and data.payload is not None else {"event": "ping", "hook_id": hook.id}
    result = dispatch_online_api_hook(db, hook=hook, payload=payload)
    log_audit_event(
        db,
        current_user=current_user,
        module="online_api_hooks",
        action="online_api_hooks.ping",
        entity_type="online_api_hook",
        entity_id=hook.id,
        details={"organization_id": hook.organization_id, "status": result["status"], "target_url": hook.target_url},
    )
    db.commit()
    return result
