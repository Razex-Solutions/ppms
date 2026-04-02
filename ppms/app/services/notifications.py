from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models.notification import Notification
from app.models.notification_delivery import NotificationDelivery
from app.models.notification_preference import NotificationPreference
from app.models.user import User
from app.services.delivery_queue import next_retry_time, should_retry
from app.services.delivery_channels import deliver_email, deliver_sms, deliver_whatsapp


def _organization_id_for_user(user: User | None) -> int | None:
    return user.station.organization_id if user and user.station else None


def _eligible_users_query(db: Session):
    return db.query(User).filter(User.is_active.is_(True))


def _distinct_users(users: list[User]) -> list[User]:
    seen: set[int] = set()
    result: list[User] = []
    for user in users:
        if user.id in seen:
            continue
        seen.add(user.id)
        result.append(user)
    return result


def notify_users(
    db: Session,
    *,
    recipients: list[User],
    actor_user: User | None,
    station_id: int | None,
    organization_id: int | None,
    event_type: str,
    title: str,
    message: str,
    entity_type: str | None = None,
    entity_id: int | None = None,
) -> list[Notification]:
    notifications: list[Notification] = []
    for recipient in _distinct_users(recipients):
        if actor_user and recipient.id == actor_user.id:
            continue
        preference = db.query(NotificationPreference).filter(
            NotificationPreference.user_id == recipient.id,
            NotificationPreference.event_type == event_type,
        ).first()
        if preference is not None and not any(
            [
                preference.in_app_enabled,
                preference.email_enabled,
                preference.sms_enabled,
                preference.whatsapp_enabled,
            ]
        ):
            continue
        notification = Notification(
            recipient_user_id=recipient.id,
            actor_user_id=actor_user.id if actor_user else None,
            station_id=station_id,
            organization_id=organization_id,
            event_type=event_type,
            title=title,
            message=message,
            entity_type=entity_type,
            entity_id=entity_id,
        )
        db.add(notification)
        db.flush()
        _create_delivery_logs(db, notification, recipient, preference)
        notifications.append(notification)
    return notifications


def _create_delivery_logs(
    db: Session,
    notification: Notification,
    recipient: User,
    preference: NotificationPreference | None,
) -> None:
    channel_states = {
        "in_app": preference.in_app_enabled if preference is not None else True,
        "email": preference.email_enabled if preference is not None else False,
        "sms": preference.sms_enabled if preference is not None else False,
        "whatsapp": preference.whatsapp_enabled if preference is not None else False,
    }
    destinations = {
        "in_app": str(recipient.id),
        "email": recipient.email,
        "sms": recipient.phone,
        "whatsapp": recipient.whatsapp_number or recipient.phone,
    }
    for channel, enabled in channel_states.items():
        if not enabled:
            continue
        destination = destinations.get(channel)
        delivery = NotificationDelivery(
            notification_id=notification.id,
            channel=channel,
            destination=destination,
            status="queued",
            detail="Queued for delivery",
        )
        db.add(delivery)
        db.flush()
        process_notification_delivery(db, delivery=delivery)


def _deliver_notification_channel(*, channel: str, destination: str | None, notification: Notification) -> tuple[str, str | None]:
    body_text = f"{notification.title}\n\n{notification.message}"
    if channel == "in_app":
        return "delivered", None
    if channel == "email":
        status, detail = deliver_email(
            to_email=destination,
            subject=notification.title,
            body_text=body_text,
            body_html=f"<h3>{notification.title}</h3><p>{notification.message}</p>",
        )
        return ("delivered" if status == "sent" else status), detail
    if channel == "sms":
        status, detail = deliver_sms(to_number=destination, body_text=body_text)
        return ("delivered" if status == "sent" else status), detail
    if channel == "whatsapp":
        status, detail = deliver_whatsapp(to_number=destination, body_text=body_text)
        return ("delivered" if status == "sent" else status), detail
    return "skipped", f"Unsupported channel {channel}"


def _get_delivery_owner(db: Session, delivery: NotificationDelivery) -> User:
    notification = db.query(Notification).filter(Notification.id == delivery.notification_id).first()
    if notification is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    recipient = db.query(User).filter(User.id == notification.recipient_user_id, User.is_active.is_(True)).first()
    if recipient is None:
        raise HTTPException(status_code=404, detail="Notification recipient not found")
    return recipient


def process_notification_delivery(db: Session, *, delivery: NotificationDelivery) -> NotificationDelivery:
    notification = db.query(Notification).filter(Notification.id == delivery.notification_id).first()
    if notification is None:
        delivery.status = "failed"
        delivery.detail = "Notification record not found"
        delivery.processed_at = utc_now()
        db.flush()
        return delivery

    delivery.attempts_count += 1
    delivery.last_attempt_at = utc_now()
    status, detail = _deliver_notification_channel(
        channel=delivery.channel,
        destination=delivery.destination,
        notification=notification,
    )
    if status in {"delivered", "skipped"}:
        delivery.status = status
        delivery.detail = detail
        delivery.next_retry_at = None
        delivery.processed_at = utc_now()
    elif should_retry(status, delivery.attempts_count):
        delivery.status = "retrying"
        delivery.detail = detail
        delivery.next_retry_at = next_retry_time(delivery.attempts_count)
        delivery.processed_at = None
    else:
        delivery.status = "failed"
        delivery.detail = detail
        delivery.next_retry_at = None
        delivery.processed_at = utc_now()
    db.flush()
    return delivery


def get_station_approvers(db: Session, station_id: int, organization_id: int | None) -> list[User]:
    users = _eligible_users_query(db).filter(User.role.has(name="Admin")).all()
    if organization_id is not None:
        users += (
            _eligible_users_query(db)
            .filter(User.role.has(name="HeadOffice"), User.station.has(organization_id=organization_id))
            .all()
        )
    return _distinct_users(users)


def get_station_watchers(db: Session, station_id: int, organization_id: int | None) -> list[User]:
    users = (
        _eligible_users_query(db)
        .filter(
            User.station_id == station_id,
            or_(User.role.has(name="Manager"), User.role.has(name="Accountant")),
        )
        .all()
    )
    if organization_id is not None:
        users += (
            _eligible_users_query(db)
            .filter(User.role.has(name="HeadOffice"), User.station.has(organization_id=organization_id))
            .all()
        )
    users += _eligible_users_query(db).filter(User.role.has(name="Admin")).all()
    return _distinct_users(users)


def list_notifications(
    db: Session,
    *,
    current_user: User,
    unread_only: bool = False,
    event_type: str | None = None,
    limit: int = 50,
    skip: int = 0,
) -> list[Notification]:
    query = db.query(Notification).filter(Notification.recipient_user_id == current_user.id)
    if unread_only:
        query = query.filter(Notification.is_read.is_(False))
    if event_type:
        query = query.filter(Notification.event_type == event_type)
    return query.order_by(Notification.created_at.desc(), Notification.id.desc()).offset(skip).limit(limit).all()


def mark_notification_read(db: Session, *, notification: Notification, current_user: User) -> Notification:
    if notification.recipient_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this notification")
    if not notification.is_read:
        notification.is_read = True
        notification.read_at = utc_now()
        db.commit()
        db.refresh(notification)
    return notification


def mark_all_notifications_read(db: Session, *, current_user: User) -> dict:
    query = db.query(Notification).filter(
        Notification.recipient_user_id == current_user.id,
        Notification.is_read.is_(False),
    )
    count = query.count()
    now = utc_now()
    query.update(
        {
            Notification.is_read: True,
            Notification.read_at: now,
        },
        synchronize_session=False,
    )
    db.commit()
    return {"marked_read": count}


def get_or_create_preference(db: Session, *, current_user: User, event_type: str) -> NotificationPreference:
    preference = db.query(NotificationPreference).filter(
        NotificationPreference.user_id == current_user.id,
        NotificationPreference.event_type == event_type,
    ).first()
    if preference is None:
        preference = NotificationPreference(user_id=current_user.id, event_type=event_type)
        db.add(preference)
        db.commit()
        db.refresh(preference)
    return preference


def list_preferences(db: Session, *, current_user: User) -> list[NotificationPreference]:
    return (
        db.query(NotificationPreference)
        .filter(NotificationPreference.user_id == current_user.id)
        .order_by(NotificationPreference.event_type.asc())
        .all()
    )


def update_preference(
    db: Session,
    *,
    current_user: User,
    event_type: str,
    in_app_enabled: bool,
    email_enabled: bool,
    sms_enabled: bool,
    whatsapp_enabled: bool,
) -> NotificationPreference:
    preference = get_or_create_preference(db, current_user=current_user, event_type=event_type)
    preference.in_app_enabled = in_app_enabled
    preference.email_enabled = email_enabled
    preference.sms_enabled = sms_enabled
    preference.whatsapp_enabled = whatsapp_enabled
    db.commit()
    db.refresh(preference)
    return preference


def notification_summary(db: Session, *, current_user: User) -> dict:
    unread_count = (
        db.query(Notification)
        .filter(Notification.recipient_user_id == current_user.id, Notification.is_read.is_(False))
        .count()
    )
    total_count = db.query(Notification).filter(Notification.recipient_user_id == current_user.id).count()
    return {"unread": unread_count, "total": total_count}


def list_deliveries(db: Session, *, current_user: User, limit: int = 50, skip: int = 0) -> list[NotificationDelivery]:
    return (
        db.query(NotificationDelivery)
        .join(Notification, Notification.id == NotificationDelivery.notification_id)
        .filter(Notification.recipient_user_id == current_user.id)
        .order_by(NotificationDelivery.created_at.desc(), NotificationDelivery.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def retry_delivery(db: Session, *, delivery: NotificationDelivery, current_user: User) -> NotificationDelivery:
    owner = _get_delivery_owner(db, delivery)
    if owner.id != current_user.id and current_user.role.name not in {"Admin", "HeadOffice"}:
        raise HTTPException(status_code=403, detail="Not authorized for this delivery")
    if delivery.status not in {"failed", "retrying"}:
        raise HTTPException(status_code=400, detail="Delivery is not eligible for retry")
    delivery.next_retry_at = None
    process_notification_delivery(db, delivery=delivery)
    db.commit()
    db.refresh(delivery)
    return delivery


def process_due_notification_deliveries(db: Session, *, limit: int = 100) -> dict:
    now = utc_now()
    deliveries = (
        db.query(NotificationDelivery)
        .filter(
            NotificationDelivery.status.in_(["queued", "retrying"]),
            or_(NotificationDelivery.next_retry_at.is_(None), NotificationDelivery.next_retry_at <= now),
        )
        .order_by(NotificationDelivery.id.asc())
        .limit(limit)
        .all()
    )
    processed = 0
    for delivery in deliveries:
        process_notification_delivery(db, delivery=delivery)
        processed += 1
    db.commit()
    return {"processed": processed}


def notify_approval_requested(
    db: Session,
    *,
    actor_user: User,
    station_id: int | None,
    organization_id: int | None,
    entity_type: str,
    entity_id: int,
    title: str,
    message: str,
    event_type: str,
) -> None:
    if station_id is None:
        return
    recipients = get_station_approvers(db, station_id, organization_id)
    notify_users(
        db,
        recipients=recipients,
        actor_user=actor_user,
        station_id=station_id,
        organization_id=organization_id,
        event_type=event_type,
        title=title,
        message=message,
        entity_type=entity_type,
        entity_id=entity_id,
    )


def notify_decision(
    db: Session,
    *,
    recipient_user_id: int | None,
    actor_user: User,
    station_id: int | None,
    organization_id: int | None,
    entity_type: str,
    entity_id: int,
    title: str,
    message: str,
    event_type: str,
) -> None:
    if recipient_user_id is None:
        return
    recipient = db.query(User).filter(User.id == recipient_user_id, User.is_active.is_(True)).first()
    if recipient is None:
        return
    notify_users(
        db,
        recipients=[recipient],
        actor_user=actor_user,
        station_id=station_id,
        organization_id=organization_id,
        event_type=event_type,
        title=title,
        message=message,
        entity_type=entity_type,
        entity_id=entity_id,
    )


def notify_actor(
    db: Session,
    *,
    actor_user: User,
    station_id: int | None,
    entity_type: str,
    entity_id: int,
    title: str,
    message: str,
    event_type: str,
) -> None:
    notify_users(
        db,
        recipients=[actor_user],
        actor_user=None,
        station_id=station_id,
        organization_id=_organization_id_for_user(actor_user),
        event_type=event_type,
        title=title,
        message=message,
        entity_type=entity_type,
        entity_id=entity_id,
    )
