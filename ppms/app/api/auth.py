from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, require_admin
from app.core.database import get_db
from app.core.permissions import (
    ROLE_CAPABILITY_SUMMARY,
    get_creatable_roles,
    get_effective_permissions,
    get_role_scope_rule,
)
from app.core.security import verify_password, create_access_token, decode_token, hash_password
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.auth import (
    AdminResetPasswordRequest,
    ChangePasswordRequest,
    LoginRequest,
    PasswordActionResponse,
    RefreshTokenRequest,
    SessionResponse,
    TokenResponse,
)
from app.services.audit import log_audit_event
from app.services.auth_sessions import (
    create_user_session,
    ensure_account_not_locked,
    get_active_session,
    list_user_sessions,
    record_failed_login,
    refresh_user_session,
    reset_login_failures,
    revoke_session,
    revoke_user_sessions,
)

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/login", response_model=TokenResponse)
def login(credentials: LoginRequest, request: Request, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == credentials.username).first()
    if user:
        ensure_account_not_locked(user)
    if not user or not verify_password(credentials.password, user.hashed_password):
        record_failed_login(db, user)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is inactive")

    reset_login_failures(user)
    session, refresh_token = create_user_session(
        db,
        user=user,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    token = create_access_token({"sub": str(user.id), "sid": session.id})
    log_audit_event(
        db,
        current_user=user,
        module="auth",
        action="auth.login",
        entity_type="session",
        entity_id=session.id,
        station_id=user.station_id,
    )
    db.commit()
    return TokenResponse(
        access_token=token,
        refresh_token=refresh_token,
        user_id=user.id,
        username=user.username,
        full_name=user.full_name,
        role_id=user.role_id,
        role_name=user.role.name,
        station_id=user.station_id,
        organization_id=get_user_organization_id(user),
        scope_level=user.scope_level,
        is_platform_user=user.is_platform_user,
    )


@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "username": current_user.username,
        "full_name": current_user.full_name,
        "email": current_user.email,
        "is_active": current_user.is_active,
        "role_id": current_user.role_id,
        "role_name": current_user.role.name,
        "station_id": current_user.station_id,
        "organization_id": get_user_organization_id(current_user),
        "scope_level": current_user.scope_level,
        "is_platform_user": current_user.is_platform_user,
        "role_summary": ROLE_CAPABILITY_SUMMARY.get(current_user.role.name),
        "role_scope_rule": get_role_scope_rule(current_user.role.name),
        "creatable_roles": get_creatable_roles(current_user.role.name),
        "permissions": get_effective_permissions(current_user),
    }


@router.post("/refresh", response_model=TokenResponse)
def refresh_auth_token(payload: RefreshTokenRequest, request: Request, db: Session = Depends(get_db)):
    session, user, refresh_token = refresh_user_session(
        db,
        refresh_token=payload.refresh_token,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    access_token = create_access_token({"sub": str(user.id), "sid": session.id})
    log_audit_event(
        db,
        current_user=user,
        module="auth",
        action="auth.refresh",
        entity_type="session",
        entity_id=session.id,
        station_id=user.station_id,
    )
    db.commit()
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user_id=user.id,
        username=user.username,
        full_name=user.full_name,
        role_id=user.role_id,
        role_name=user.role.name,
        station_id=user.station_id,
        organization_id=get_user_organization_id(user),
        scope_level=user.scope_level,
        is_platform_user=user.is_platform_user,
    )


@router.get("/sessions", response_model=list[SessionResponse])
def get_my_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sessions = list_user_sessions(db, user=current_user)
    return [
        SessionResponse(
            id=session.id,
            is_active=session.is_active,
            created_at=session.created_at.isoformat(),
            expires_at=session.expires_at.isoformat(),
            revoked_at=session.revoked_at.isoformat() if session.revoked_at else None,
            last_seen_at=session.last_seen_at.isoformat() if session.last_seen_at else None,
            ip_address=session.ip_address,
            user_agent=session.user_agent,
        )
        for session in sessions
    ]


@router.post("/logout", response_model=PasswordActionResponse)
def logout(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "", 1).strip()
    payload = decode_token(token) if token else None
    session = None
    if payload and payload.get("sid"):
        session = get_active_session(db, int(payload["sid"]))
    if session:
        revoke_session(session)
        log_audit_event(
            db,
            current_user=current_user,
            module="auth",
            action="auth.logout",
            entity_type="session",
            entity_id=session.id,
            station_id=current_user.station_id,
        )
        db.commit()
    return PasswordActionResponse(message="Logged out successfully")


@router.post("/logout-all", response_model=PasswordActionResponse)
def logout_all(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "", 1).strip()
    payload = decode_token(token) if token else None
    current_session_id = int(payload["sid"]) if payload and payload.get("sid") else None
    revoked_count = revoke_user_sessions(db, user=current_user, except_session_id=current_session_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="auth",
        action="auth.logout_all",
        entity_type="session",
        station_id=current_user.station_id,
        details={"revoked_sessions": revoked_count},
    )
    db.commit()
    return PasswordActionResponse(message="Other sessions logged out successfully")


@router.post("/change-password", response_model=PasswordActionResponse)
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(payload.current_password, current_user.hashed_password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Current password is incorrect")
    if payload.current_password == payload.new_password:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="New password must be different from the current password")

    try:
        current_user.hashed_password = hash_password(payload.new_password)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    revoke_user_sessions(db, user=current_user)

    log_audit_event(
        db,
        current_user=current_user,
        module="auth",
        action="auth.change_password",
        entity_type="user",
        entity_id=current_user.id,
        station_id=current_user.station_id,
    )
    db.commit()
    return PasswordActionResponse(message="Password changed successfully")


@router.post("/admin-reset-password/{user_id}", response_model=PasswordActionResponse)
def admin_reset_password(
    user_id: int,
    payload: AdminResetPasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_admin(current_user)
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    try:
        user.hashed_password = hash_password(payload.new_password)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    revoke_user_sessions(db, user=user)

    log_audit_event(
        db,
        current_user=current_user,
        module="auth",
        action="auth.admin_reset_password",
        entity_type="user",
        entity_id=user.id,
        station_id=user.station_id,
        details={"target_username": user.username},
    )
    db.commit()
    return PasswordActionResponse(message="Password reset successfully")
