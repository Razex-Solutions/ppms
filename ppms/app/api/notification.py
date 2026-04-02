from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.notification import Notification
from app.models.notification_delivery import NotificationDelivery
from app.models.user import User
from app.schemas.notification_delivery import NotificationDeliveryResponse
from app.schemas.notification import NotificationResponse
from app.schemas.notification_preference import NotificationPreferenceResponse, NotificationPreferenceUpdate
from app.services.notifications import (
    list_notifications,
    list_preferences,
    list_deliveries,
    mark_all_notifications_read,
    mark_notification_read,
    notification_summary,
    process_due_notification_deliveries,
    retry_delivery,
    update_preference,
)

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/", response_model=list[NotificationResponse])
def get_notifications(
    unread_only: bool = Query(False),
    event_type: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "notifications", "read", detail="You do not have permission to view notifications")
    return list_notifications(
        db,
        current_user=current_user,
        unread_only=unread_only,
        event_type=event_type,
        skip=skip,
        limit=limit,
    )


@router.post("/{notification_id}/read", response_model=NotificationResponse)
def read_notification(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "notifications", "read", detail="You do not have permission to update notifications")
    notification = db.query(Notification).filter(Notification.id == notification_id).first()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return mark_notification_read(db, notification=notification, current_user=current_user)


@router.post("/read-all")
def read_all_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "notifications", "read", detail="You do not have permission to update notifications")
    return mark_all_notifications_read(db, current_user=current_user)


@router.get("/summary")
def get_notification_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "notifications", "read", detail="You do not have permission to view notifications")
    return notification_summary(db, current_user=current_user)


@router.get("/preferences", response_model=list[NotificationPreferenceResponse])
def get_preferences(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "notifications", "read", detail="You do not have permission to view notification preferences")
    return list_preferences(db, current_user=current_user)


@router.put("/preferences/{event_type}", response_model=NotificationPreferenceResponse)
def put_preference(
    event_type: str,
    data: NotificationPreferenceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "notifications", "read", detail="You do not have permission to update notification preferences")
    return update_preference(
        db,
        current_user=current_user,
        event_type=event_type,
        in_app_enabled=data.in_app_enabled,
        email_enabled=data.email_enabled,
        sms_enabled=data.sms_enabled,
        whatsapp_enabled=data.whatsapp_enabled,
    )


@router.get("/deliveries", response_model=list[NotificationDeliveryResponse])
def get_notification_deliveries(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "notifications", "read", detail="You do not have permission to view notification deliveries")
    return list_deliveries(db, current_user=current_user, skip=skip, limit=limit)


@router.post("/deliveries/process-due")
def process_due_notification_deliveries_endpoint(
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "delivery_jobs", "process", detail="You do not have permission to process delivery jobs")
    return process_due_notification_deliveries(db, limit=limit)


@router.post("/deliveries/{delivery_id}/retry", response_model=NotificationDeliveryResponse)
def retry_notification_delivery(
    delivery_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "notifications", "read", detail="You do not have permission to retry notification deliveries")
    notification_delivery = db.query(NotificationDelivery).filter(NotificationDelivery.id == delivery_id).first()
    if not notification_delivery:
        raise HTTPException(status_code=404, detail="Notification delivery not found")
    return retry_delivery(db, delivery=notification_delivery, current_user=current_user)
