import hashlib
import hmac
import json

import requests
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.config import APP_ENV, ONLINE_HOOKS_MODE
from app.core.time import utc_now
from app.models.online_api_hook import OnlineAPIHook
from app.schemas.online_api_hook import OnlineAPIHookCreate, OnlineAPIHookUpdate
from app.services.saas import ensure_organization_access


VALID_AUTH_TYPES = {"none", "bearer"}


def list_online_api_hooks(db: Session, organization_id: int):
    return (
        db.query(OnlineAPIHook)
        .filter(OnlineAPIHook.organization_id == organization_id)
        .order_by(OnlineAPIHook.created_at.desc(), OnlineAPIHook.id.desc())
        .all()
    )


def create_online_api_hook(db: Session, organization_id: int, data: OnlineAPIHookCreate) -> OnlineAPIHook:
    if data.auth_type not in VALID_AUTH_TYPES:
        raise HTTPException(status_code=400, detail="Invalid online hook auth type")
    hook = OnlineAPIHook(organization_id=organization_id, **data.model_dump())
    db.add(hook)
    db.commit()
    db.refresh(hook)
    return hook


def update_online_api_hook(db: Session, hook: OnlineAPIHook, data: OnlineAPIHookUpdate) -> OnlineAPIHook:
    payload = data.model_dump(exclude_unset=True)
    if "auth_type" in payload and payload["auth_type"] not in VALID_AUTH_TYPES:
        raise HTTPException(status_code=400, detail="Invalid online hook auth type")
    for field, value in payload.items():
        setattr(hook, field, value)
    db.commit()
    db.refresh(hook)
    return hook


def dispatch_online_api_hook(
    db: Session,
    *,
    hook: OnlineAPIHook,
    payload: dict,
) -> dict:
    headers = {"Content-Type": "application/json"}
    body = json.dumps(payload, sort_keys=True).encode("utf-8")
    if hook.auth_type == "bearer" and hook.auth_token:
        headers["Authorization"] = f"Bearer {hook.auth_token}"
    if hook.secret_key:
        signature = hmac.new(hook.secret_key.encode("utf-8"), body, hashlib.sha256).hexdigest()
        headers["X-PPMS-Signature"] = signature

    hook.last_triggered_at = utc_now()
    if ONLINE_HOOKS_MODE == "mock" or APP_ENV in {"development", "test"}:
        hook.last_status = "sent"
        hook.last_detail = f"Mock hook delivery to {hook.target_url}"
        db.commit()
        db.refresh(hook)
        return {"status": hook.last_status, "detail": hook.last_detail}

    try:
        response = requests.post(hook.target_url, data=body, headers=headers, timeout=20)
        if response.ok:
            hook.last_status = "sent"
            hook.last_detail = None
        else:
            hook.last_status = "failed"
            hook.last_detail = f"HTTP {response.status_code}"
        db.commit()
        db.refresh(hook)
        return {"status": hook.last_status, "detail": hook.last_detail}
    except Exception as exc:
        hook.last_status = "failed"
        hook.last_detail = f"Hook delivery failed: {exc}"
        db.commit()
        db.refresh(hook)
        return {"status": hook.last_status, "detail": hook.last_detail}


def ensure_online_hook_access(db: Session, organization_id: int, current_user):
    return ensure_organization_access(db, organization_id, current_user)
