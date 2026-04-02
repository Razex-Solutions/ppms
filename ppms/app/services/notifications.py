from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models.notification import Notification
from app.models.user import User


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
        notifications.append(notification)
    return notifications


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
