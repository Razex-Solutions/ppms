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


class RoleSummaryResponse(BaseModel):
    scope: str
    governance: str
    operations: str


class RoleScopeRuleResponse(BaseModel):
    scope_level: str
    requires_organization: bool
    requires_station: bool
    platform_only: bool


class ModuleSettingSummaryResponse(BaseModel):
    module_name: str
    is_enabled: bool


class SubscriptionSummaryResponse(BaseModel):
    id: int
    status: str
    billing_cycle: str
    auto_renew: bool
    plan_id: int | None = None
    plan_name: str | None = None
    plan_code: str | None = None


class AuthMeResponse(BaseModel):
    id: int
    username: str
    full_name: str
    email: str | None = None
    is_active: bool
    role_id: int
    role_name: str
    station_id: int | None = None
    organization_id: int | None = None
    scope_level: str | None = None
    is_platform_user: bool = False
    role_summary: RoleSummaryResponse | None = None
    role_scope_rule: RoleScopeRuleResponse
    creatable_roles: list[str]
    permissions: dict[str, list[str]]
    backend_enabled_modules: list[str]
    effective_enabled_modules: list[str]
    organization_modules: list[ModuleSettingSummaryResponse]
    station_modules: list[ModuleSettingSummaryResponse]
    feature_flags: dict[str, bool]
    subscription: SubscriptionSummaryResponse | None = None
