from datetime import datetime

from pydantic import BaseModel, ConfigDict


class SubscriptionPlanCreate(BaseModel):
    name: str
    code: str
    description: str | None = None
    monthly_price: float = 0
    yearly_price: float | None = None
    max_stations: int | None = None
    max_users: int | None = None
    feature_summary: str | None = None
    is_active: bool = True
    is_default: bool = False


class SubscriptionPlanUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    description: str | None = None
    monthly_price: float | None = None
    yearly_price: float | None = None
    max_stations: int | None = None
    max_users: int | None = None
    feature_summary: str | None = None
    is_active: bool | None = None
    is_default: bool | None = None


class SubscriptionPlanResponse(BaseModel):
    id: int
    name: str
    code: str
    description: str | None = None
    monthly_price: float
    yearly_price: float | None = None
    max_stations: int | None = None
    max_users: int | None = None
    feature_summary: str | None = None
    is_active: bool
    is_default: bool

    model_config = ConfigDict(from_attributes=True)


class OrganizationSubscriptionUpsert(BaseModel):
    plan_id: int | None = None
    status: str = "inactive"
    billing_cycle: str = "monthly"
    start_date: datetime | None = None
    end_date: datetime | None = None
    trial_ends_at: datetime | None = None
    auto_renew: bool = False
    price_override: float | None = None
    notes: str | None = None


class OrganizationSubscriptionResponse(BaseModel):
    id: int
    organization_id: int
    plan_id: int | None = None
    status: str
    billing_cycle: str
    start_date: datetime | None = None
    end_date: datetime | None = None
    trial_ends_at: datetime | None = None
    auto_renew: bool
    price_override: float | None = None
    notes: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
