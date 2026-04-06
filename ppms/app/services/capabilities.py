from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id
from app.core.config import ENABLED_MODULES
from app.models.organization_module_setting import OrganizationModuleSetting
from app.models.organization_subscription import OrganizationSubscription
from app.models.station_module_setting import StationModuleSetting
from app.models.user import User


MODULE_TOGGLE_ALIASES: dict[str, set[str]] = {
    "tanker_operations": {"tankers"},
}

KNOWN_BACKEND_MODULES = {
    "accounting",
    "attendance",
    "audit_logs",
    "auth",
    "brands",
    "customer_payments",
    "customers",
    "dashboard",
    "dispensers",
    "document_templates",
    "employee_profiles",
    "expenses",
    "financial_documents",
    "fuel_sales",
    "fuel_types",
    "hardware",
    "internal_fuel_usage",
    "invoice_profiles",
    "ledger",
    "maintenance",
    "notifications",
    "nozzles",
    "online_api_hooks",
    "online_api_hooks_public",
    "organization_modules",
    "organizations",
    "payroll",
    "pos_products",
    "pos_sales",
    "purchases",
    "report_definitions",
    "report_exports",
    "reports",
    "roles",
    "saas",
    "salary_adjustments",
    "shifts",
    "station_modules",
    "station_shift_templates",
    "stations",
    "supplier_payments",
    "suppliers",
    "tank_dips",
    "tankers",
    "tanks",
    "users",
}


def resolve_backend_enabled_modules(configured_modules: str | None = None) -> set[str]:
    configured = (configured_modules or ENABLED_MODULES).strip()
    if configured == "*" or configured == "":
        return set(KNOWN_BACKEND_MODULES)
    return {
        item.strip()
        for item in configured.split(",")
        if item.strip()
    }


def get_capability_context(db: Session, current_user: User) -> dict[str, object]:
    backend_enabled_modules = resolve_backend_enabled_modules()
    effective_enabled_modules = set(backend_enabled_modules)
    organization_id = get_user_organization_id(current_user)

    organization_settings = []
    if organization_id is not None:
        organization_settings = (
            db.query(OrganizationModuleSetting)
            .filter(OrganizationModuleSetting.organization_id == organization_id)
            .all()
        )

    station_settings = []
    if current_user.station_id is not None:
        station_settings = (
            db.query(StationModuleSetting)
            .filter(StationModuleSetting.station_id == current_user.station_id)
            .all()
        )

    feature_flags: dict[str, bool] = {}
    for setting in [*organization_settings, *station_settings]:
        feature_flags[setting.module_name] = bool(setting.is_enabled)
        if setting.module_name in backend_enabled_modules:
            if setting.is_enabled:
                effective_enabled_modules.add(setting.module_name)
            else:
                effective_enabled_modules.discard(setting.module_name)
        for alias in MODULE_TOGGLE_ALIASES.get(setting.module_name, set()):
            if setting.is_enabled and alias in backend_enabled_modules:
                effective_enabled_modules.add(alias)
            else:
                effective_enabled_modules.discard(alias)

    if current_user.station is not None:
        allow_meter_adjustments = bool(current_user.station.allow_meter_adjustments)
        feature_flags["meter_adjustments"] = allow_meter_adjustments
        if allow_meter_adjustments:
            effective_enabled_modules.add("meter_adjustments")
        else:
            effective_enabled_modules.discard("meter_adjustments")

    subscription_summary = None
    if organization_id is not None:
        subscription = (
            db.query(OrganizationSubscription)
            .filter(OrganizationSubscription.organization_id == organization_id)
            .first()
        )
        if subscription is not None:
            subscription_summary = {
                "id": subscription.id,
                "status": subscription.status,
                "billing_cycle": subscription.billing_cycle,
                "auto_renew": subscription.auto_renew,
                "plan_id": subscription.plan_id,
                "plan_name": subscription.plan.name if subscription.plan else None,
                "plan_code": subscription.plan.code if subscription.plan else None,
            }

    return {
        "backend_enabled_modules": sorted(backend_enabled_modules),
        "effective_enabled_modules": sorted(effective_enabled_modules),
        "organization_modules": [
            {"module_name": setting.module_name, "is_enabled": setting.is_enabled}
            for setting in organization_settings
        ],
        "station_modules": [
            {"module_name": setting.module_name, "is_enabled": setting.is_enabled}
            for setting in station_settings
        ],
        "feature_flags": feature_flags,
        "subscription": subscription_summary,
    }
