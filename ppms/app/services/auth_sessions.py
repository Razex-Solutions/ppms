from datetime import timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import ACCOUNT_LOCK_MINUTES, MAX_FAILED_LOGIN_ATTEMPTS
from app.core.security import create_refresh_token, hash_token
from app.core.time import utc_now
from app.models.auth_session import AuthSession
from app.models.user import User


def ensure_account_not_locked(user: User) -> None:
    if user.locked_until and user.locked_until > utc_now():
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail=f"Account is temporarily locked until {user.locked_until.isoformat()}",
        )


def record_failed_login(db: Session, user: User | None) -> None:
    if not user:
        return

    user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
    user.last_failed_login_at = utc_now()
    if user.failed_login_attempts >= MAX_FAILED_LOGIN_ATTEMPTS:
        user.locked_until = utc_now().replace(microsecond=0) + timedelta(minutes=ACCOUNT_LOCK_MINUTES)
        user.failed_login_attempts = 0
    db.commit()


def reset_login_failures(user: User) -> None:
    user.failed_login_attempts = 0
    user.last_failed_login_at = None
    user.locked_until = None
    user.last_login_at = utc_now()


def create_user_session(
    db: Session,
    *,
    user: User,
    ip_address: str | None,
    user_agent: str | None,
) -> tuple[AuthSession, str]:
    refresh_token, refresh_token_hash, expires_at = create_refresh_token()
    now = utc_now()
    session = AuthSession(
        user_id=user.id,
        refresh_token_hash=refresh_token_hash,
        is_active=True,
        expires_at=expires_at,
        last_seen_at=now,
        ip_address=ip_address,
        user_agent=user_agent,
        created_at=now,
        updated_at=now,
    )
    db.add(session)
    db.flush()
    return session, refresh_token


def refresh_user_session(db: Session, *, refresh_token: str, ip_address: str | None, user_agent: str | None) -> tuple[AuthSession, User, str]:
    session = (
        db.query(AuthSession)
        .join(User, User.id == AuthSession.user_id)
        .filter(AuthSession.refresh_token_hash == hash_token(refresh_token))
        .first()
    )
    if not session or not session.is_active or session.revoked_at or session.expires_at <= utc_now():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    user = session.user
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    ensure_account_not_locked(user)

    new_refresh_token, new_hash, expires_at = create_refresh_token()
    session.refresh_token_hash = new_hash
    session.expires_at = expires_at
    session.last_seen_at = utc_now()
    session.updated_at = utc_now()
    if ip_address:
        session.ip_address = ip_address
    if user_agent:
        session.user_agent = user_agent
    db.flush()
    return session, user, new_refresh_token


def get_active_session(db: Session, session_id: int) -> AuthSession | None:
    return (
        db.query(AuthSession)
        .filter(AuthSession.id == session_id, AuthSession.is_active.is_(True), AuthSession.revoked_at.is_(None))
        .first()
    )


def revoke_session(session: AuthSession) -> None:
    session.is_active = False
    session.revoked_at = utc_now()
    session.updated_at = utc_now()


def revoke_user_sessions(db: Session, *, user: User, except_session_id: int | None = None) -> int:
    sessions = (
        db.query(AuthSession)
        .filter(AuthSession.user_id == user.id, AuthSession.is_active.is_(True), AuthSession.revoked_at.is_(None))
        .all()
    )
    count = 0
    for session in sessions:
        if except_session_id and session.id == except_session_id:
            continue
        revoke_session(session)
        count += 1
    return count


def list_user_sessions(db: Session, *, user: User) -> list[AuthSession]:
    return (
        db.query(AuthSession)
        .filter(AuthSession.user_id == user.id)
        .order_by(AuthSession.created_at.desc(), AuthSession.id.desc())
        .all()
    )
