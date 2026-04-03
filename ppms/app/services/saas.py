from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.models.organization import Organization
from app.models.organization_subscription import OrganizationSubscription
from app.models.subscription_plan import SubscriptionPlan
from app.models.user import User
from app.schemas.saas import OrganizationSubscriptionUpsert, SubscriptionPlanCreate, SubscriptionPlanUpdate


def ensure_organization_access(db: Session, organization_id: int, current_user: User) -> Organization:
    organization = db.query(Organization).filter(Organization.id == organization_id).first()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return organization
    if is_head_office_user(current_user) and get_user_organization_id(current_user) == organization_id:
        return organization
    raise HTTPException(status_code=403, detail="Not authorized for this organization")


def create_subscription_plan(db: Session, data: SubscriptionPlanCreate) -> SubscriptionPlan:
    existing = db.query(SubscriptionPlan).filter(SubscriptionPlan.code == data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Subscription plan code already exists")
    if data.is_default:
        db.query(SubscriptionPlan).update({SubscriptionPlan.is_default: False}, synchronize_session=False)
    plan = SubscriptionPlan(**data.model_dump())
    db.add(plan)
    db.commit()
    db.refresh(plan)
    return plan


def update_subscription_plan(db: Session, plan: SubscriptionPlan, data: SubscriptionPlanUpdate) -> SubscriptionPlan:
    payload = data.model_dump(exclude_unset=True)
    if "code" in payload:
        existing = (
            db.query(SubscriptionPlan)
            .filter(SubscriptionPlan.code == payload["code"], SubscriptionPlan.id != plan.id)
            .first()
        )
        if existing:
            raise HTTPException(status_code=400, detail="Subscription plan code already exists")
    if payload.get("is_default"):
        db.query(SubscriptionPlan).update({SubscriptionPlan.is_default: False}, synchronize_session=False)
    for field, value in payload.items():
        setattr(plan, field, value)
    db.commit()
    db.refresh(plan)
    return plan


def get_or_create_subscription(db: Session, organization_id: int) -> OrganizationSubscription:
    subscription = (
        db.query(OrganizationSubscription)
        .filter(OrganizationSubscription.organization_id == organization_id)
        .first()
    )
    if subscription is None:
        default_plan = (
            db.query(SubscriptionPlan)
            .filter(SubscriptionPlan.is_default.is_(True), SubscriptionPlan.is_active.is_(True))
            .first()
        )
        subscription = OrganizationSubscription(
            organization_id=organization_id,
            plan_id=default_plan.id if default_plan else None,
            status="inactive",
            billing_cycle="monthly",
        )
        db.add(subscription)
        db.commit()
        db.refresh(subscription)
    return subscription


def upsert_organization_subscription(
    db: Session,
    *,
    organization_id: int,
    data: OrganizationSubscriptionUpsert,
) -> OrganizationSubscription:
    subscription = get_or_create_subscription(db, organization_id)
    if data.plan_id is not None:
        plan = db.query(SubscriptionPlan).filter(SubscriptionPlan.id == data.plan_id).first()
        if not plan:
            raise HTTPException(status_code=404, detail="Subscription plan not found")
    for field, value in data.model_dump().items():
        setattr(subscription, field, value)
    db.commit()
    db.refresh(subscription)
    return subscription
