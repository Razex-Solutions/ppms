from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class AdminResetPasswordRequest(BaseModel):
    new_password: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class PasswordActionResponse(BaseModel):
    message: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: int
    username: str
    full_name: str
    role_id: int
    role_name: str | None = None
    station_id: int | None = None
    organization_id: int | None = None
    scope_level: str | None = None
    is_platform_user: bool = False


class SessionResponse(BaseModel):
    id: int
    is_active: bool
    created_at: str
    expires_at: str
    revoked_at: str | None = None
    last_seen_at: str | None = None
    ip_address: str | None = None
    user_agent: str | None = None
