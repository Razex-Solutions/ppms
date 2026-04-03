import base64
import hashlib
import hmac
import json

import requests
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.config import APP_ENV, ONLINE_HOOKS_MODE
from app.core.time import utc_now
from app.models.inbound_webhook_event import InboundWebhookEvent
from app.models.online_api_hook import OnlineAPIHook
from app.schemas.online_api_hook import OnlineAPIHookCreate, OnlineAPIHookUpdate
from app.services.saas import ensure_organization_access


VALID_AUTH_TYPES = {"none", "bearer", "basic", "hmac_sha256"}
DEFAULT_SIGNATURE_HEADER = "X-PPMS-Signature"
SUPPORTED_EVENT_TYPES = [
    "expense.approval_requested",
    "expense.approved",
    "expense.rejected",
    "purchase.approval_requested",
    "purchase.approved",
    "purchase.rejected",
    "fuel_sale.reversal_requested",
    "fuel_sale.reversal_approved",
    "customer_payment.reversal_requested",
    "supplier_payment.reversal_requested",
    "financial_document.dispatched",
    "report_export.completed",
    "nozzle.meter_adjusted",
]


def list_supported_hook_event_types() -> list[str]:
    return SUPPORTED_EVENT_TYPES


def list_online_api_hooks(db: Session, organization_id: int, *, event_type: str | None = None, active_only: bool = False):
    query = db.query(OnlineAPIHook).filter(OnlineAPIHook.organization_id == organization_id)
    if event_type:
        query = query.filter(OnlineAPIHook.event_type == event_type)
    if active_only:
        query = query.filter(OnlineAPIHook.is_active.is_(True))
    return query.order_by(OnlineAPIHook.created_at.desc(), OnlineAPIHook.id.desc()).all()


def create_online_api_hook(db: Session, organization_id: int, data: OnlineAPIHookCreate) -> OnlineAPIHook:
    if data.auth_type not in VALID_AUTH_TYPES:
        raise HTTPException(status_code=400, detail="Invalid online hook auth type")
    if data.event_type not in SUPPORTED_EVENT_TYPES and data.event_type != "custom":
        raise HTTPException(status_code=400, detail="Unsupported online hook event type")
    hook = OnlineAPIHook(organization_id=organization_id, **data.model_dump())
    if hook.auth_type == "hmac_sha256" and not hook.secret_key:
        raise HTTPException(status_code=400, detail="Secret key is required for hmac_sha256 hooks")
    if hook.auth_type == "basic" and not hook.auth_token:
        raise HTTPException(status_code=400, detail="Auth token is required for basic hooks")
    if hook.auth_type == "hmac_sha256" and not hook.signature_header:
        hook.signature_header = DEFAULT_SIGNATURE_HEADER
    db.add(hook)
    db.commit()
    db.refresh(hook)
    return hook


def update_online_api_hook(db: Session, hook: OnlineAPIHook, data: OnlineAPIHookUpdate) -> OnlineAPIHook:
    payload = data.model_dump(exclude_unset=True)
    if "auth_type" in payload and payload["auth_type"] not in VALID_AUTH_TYPES:
        raise HTTPException(status_code=400, detail="Invalid online hook auth type")
    if "event_type" in payload and payload["event_type"] not in SUPPORTED_EVENT_TYPES and payload["event_type"] != "custom":
        raise HTTPException(status_code=400, detail="Unsupported online hook event type")
    for field, value in payload.items():
        setattr(hook, field, value)
    if hook.auth_type == "hmac_sha256" and not hook.secret_key:
        raise HTTPException(status_code=400, detail="Secret key is required for hmac_sha256 hooks")
    if hook.auth_type == "basic" and not hook.auth_token:
        raise HTTPException(status_code=400, detail="Auth token is required for basic hooks")
    if hook.auth_type == "hmac_sha256" and not hook.signature_header:
        hook.signature_header = DEFAULT_SIGNATURE_HEADER
    db.commit()
    db.refresh(hook)
    return hook


def _build_hook_headers(hook: OnlineAPIHook, body: bytes) -> dict:
    headers = {"Content-Type": "application/json"}
    if hook.auth_type == "bearer" and hook.auth_token:
        headers["Authorization"] = f"Bearer {hook.auth_token}"
    elif hook.auth_type == "basic" and hook.auth_token:
        encoded = base64.b64encode(hook.auth_token.encode("utf-8")).decode("utf-8")
        headers["Authorization"] = f"Basic {encoded}"
    if hook.secret_key:
        signature = hmac.new(hook.secret_key.encode("utf-8"), body, hashlib.sha256).hexdigest()
        headers[hook.signature_header or DEFAULT_SIGNATURE_HEADER] = f"sha256={signature}"
    return headers


def dispatch_online_api_hook(
    db: Session,
    *,
    hook: OnlineAPIHook,
    payload: dict,
) -> dict:
    body = json.dumps(payload, sort_keys=True).encode("utf-8")
    headers = _build_hook_headers(hook, body)

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


def receive_inbound_webhook(
    db: Session,
    *,
    organization_id: int,
    hook_name: str,
    event_type: str,
    headers: dict,
    payload: dict,
) -> InboundWebhookEvent:
    hook = (
        db.query(OnlineAPIHook)
        .filter(
            OnlineAPIHook.organization_id == organization_id,
            OnlineAPIHook.name == hook_name,
            OnlineAPIHook.is_active.is_(True),
        )
        .first()
    )
    if not hook:
        raise HTTPException(status_code=404, detail="Inbound hook target not found")

    body = json.dumps(payload, sort_keys=True).encode("utf-8")
    status = "received"
    detail = None
    if hook.secret_key:
        provided_signature = headers.get((hook.signature_header or DEFAULT_SIGNATURE_HEADER).lower())
        raw_secret = headers.get("x-ppms-integration-key")
        expected_signature = hmac.new(hook.secret_key.encode("utf-8"), body, hashlib.sha256).hexdigest()
        expected_value = f"sha256={expected_signature}"
        if raw_secret == hook.secret_key:
            pass
        elif provided_signature != expected_value:
            status = "rejected"
            detail = "Invalid webhook signature"

    event = InboundWebhookEvent(
        organization_id=organization_id,
        hook_name=hook_name,
        event_type=event_type or hook.event_type,
        source="external",
        headers_json=json.dumps(headers, sort_keys=True),
        payload_json=json.dumps(payload, sort_keys=True),
        status=status,
        detail=detail,
    )
    db.add(event)
    db.commit()
    db.refresh(event)

    if status == "rejected":
        raise HTTPException(status_code=401, detail="Invalid inbound webhook signature")
    return event


def list_inbound_webhook_events(
    db: Session,
    *,
    organization_id: int,
    event_type: str | None = None,
    status: str | None = None,
):
    query = db.query(InboundWebhookEvent).filter(InboundWebhookEvent.organization_id == organization_id)
    if event_type:
        query = query.filter(InboundWebhookEvent.event_type == event_type)
    if status:
        query = query.filter(InboundWebhookEvent.status == status)
    return query.order_by(InboundWebhookEvent.received_at.desc(), InboundWebhookEvent.id.desc()).all()


def online_hook_diagnostics(db: Session, *, organization_id: int) -> dict:
    hooks = db.query(OnlineAPIHook).filter(OnlineAPIHook.organization_id == organization_id).all()
    inbound_events = db.query(InboundWebhookEvent).filter(InboundWebhookEvent.organization_id == organization_id).all()
    return {
        "hook_count": len(hooks),
        "active_hook_count": sum(1 for hook in hooks if hook.is_active),
        "failed_hook_count": sum(1 for hook in hooks if hook.last_status == "failed"),
        "inbound_event_count": len(inbound_events),
        "rejected_inbound_event_count": sum(1 for event in inbound_events if event.status == "rejected"),
    }


def ensure_online_hook_access(db: Session, organization_id: int, current_user):
    return ensure_organization_access(db, organization_id, current_user)
