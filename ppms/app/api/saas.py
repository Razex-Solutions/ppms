from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.organization_subscription import OrganizationSubscription
from app.models.subscription_plan import SubscriptionPlan
from app.models.user import User
from app.schemas.saas import (
    OrganizationSubscriptionResponse,
    OrganizationSubscriptionUpsert,
    SubscriptionPlanCreate,
    SubscriptionPlanResponse,
    SubscriptionPlanUpdate,
)
from app.services.audit import log_audit_event
from app.services.saas import (
    create_subscription_plan,
    ensure_organization_access,
    get_or_create_subscription,
    update_subscription_plan,
    upsert_organization_subscription,
)


router = APIRouter(prefix="/saas", tags=["SaaS"])


@router.post("/plans", response_model=SubscriptionPlanResponse)
def create_plan(
    data: SubscriptionPlanCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "saas", "manage", detail="You do not have permission to manage SaaS plans")
    plan = create_subscription_plan(db, data)
    log_audit_event(
        db,
        current_user=current_user,
        module="saas",
        action="saas.plan_create",
        entity_type="subscription_plan",
        entity_id=plan.id,
        details={"code": plan.code, "name": plan.name},
    )
    db.commit()
    db.refresh(plan)
    return plan


@router.get("/plans", response_model=list[SubscriptionPlanResponse])
def list_plans(
    is_active: bool | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "saas", "read", detail="You do not have permission to view SaaS plans")
    query = db.query(SubscriptionPlan)
    if is_active is not None:
        query = query.filter(SubscriptionPlan.is_active == is_active)
    return query.order_by(SubscriptionPlan.name.asc()).all()


@router.put("/plans/{plan_id}", response_model=SubscriptionPlanResponse)
def update_plan(
    plan_id: int,
    data: SubscriptionPlanUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "saas", "manage", detail="You do not have permission to manage SaaS plans")
    plan = db.query(SubscriptionPlan).filter(SubscriptionPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Subscription plan not found")
    plan = update_subscription_plan(db, plan, data)
    log_audit_event(
        db,
        current_user=current_user,
        module="saas",
        action="saas.plan_update",
        entity_type="subscription_plan",
        entity_id=plan.id,
        details={"code": plan.code, "name": plan.name},
    )
    db.commit()
    db.refresh(plan)
    return plan


@router.get("/organizations/{organization_id}/subscription", response_model=OrganizationSubscriptionResponse)
def get_subscription(
    organization_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "saas", "read", detail="You do not have permission to view SaaS subscriptions")
    ensure_organization_access(db, organization_id, current_user)
    return get_or_create_subscription(db, organization_id)


@router.put("/organizations/{organization_id}/subscription", response_model=OrganizationSubscriptionResponse)
def put_subscription(
    organization_id: int,
    data: OrganizationSubscriptionUpsert,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "saas", "manage", detail="You do not have permission to manage SaaS subscriptions")
    ensure_organization_access(db, organization_id, current_user)
    subscription = upsert_organization_subscription(db, organization_id=organization_id, data=data)
    log_audit_event(
        db,
        current_user=current_user,
        module="saas",
        action="saas.subscription_update",
        entity_type="organization_subscription",
        entity_id=subscription.id,
        details={"organization_id": organization_id, "status": subscription.status, "plan_id": subscription.plan_id},
    )
    db.commit()
    db.refresh(subscription)
    return subscription
