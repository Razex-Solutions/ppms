from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.station import Station
from app.models.user import User
from app.services.audit import log_audit_event
from app.services.reports import (
    build_customer_balance_report,
    build_daily_closing_report,
    build_shift_variance_report,
    build_stock_movement_report,
    build_supplier_balance_report,
    build_tanker_delivery_report,
    build_tanker_expense_report,
    build_tanker_profit_report,
)

router = APIRouter(prefix="/reports", tags=["Reports"])


def _resolve_report_scope(
    db: Session,
    current_user: User,
    station_id: int | None,
    organization_id: int | None,
) -> tuple[int | None, int | None]:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        if station_id is not None and organization_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Station does not belong to the requested organization")
        return station_id, organization_id

    if is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        if organization_id is None:
            raise HTTPException(status_code=403, detail="Head office user must belong to an organization")
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Station does not belong to your organization")
        return station_id, organization_id

    return current_user.station_id, get_user_organization_id(current_user)


@router.get("/daily-closing")
def daily_closing_report(
    report_date: date = Query(...),
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id, organization_id = _resolve_report_scope(db, current_user, station_id, organization_id)
    report = build_daily_closing_report(db, station_id, report_date, organization_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.daily_closing",
        entity_type="report",
        station_id=station_id,
        details={"report_date": str(report_date), "organization_id": organization_id},
    )
    db.commit()
    return report


@router.get("/shift-variance")
def shift_variance_report(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id, organization_id = _resolve_report_scope(db, current_user, station_id, organization_id)
    report = build_shift_variance_report(db, station_id, from_date, to_date, organization_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.shift_variance",
        entity_type="report",
        station_id=station_id,
        details={
            "from_date": str(from_date) if from_date else None,
            "to_date": str(to_date) if to_date else None,
            "organization_id": organization_id,
        },
    )
    db.commit()
    return report


@router.get("/stock-movement")
def stock_movement_report(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id, organization_id = _resolve_report_scope(db, current_user, station_id, organization_id)
    report = build_stock_movement_report(db, station_id, from_date, to_date, organization_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.stock_movement",
        entity_type="report",
        station_id=station_id,
        details={
            "from_date": str(from_date) if from_date else None,
            "to_date": str(to_date) if to_date else None,
            "organization_id": organization_id,
        },
    )
    db.commit()
    return report


@router.get("/customer-balances")
def customer_balance_report(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id, organization_id = _resolve_report_scope(db, current_user, station_id, organization_id)
    report = build_customer_balance_report(db, station_id, organization_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.customer_balances",
        entity_type="report",
        station_id=station_id,
        details={"organization_id": organization_id},
    )
    db.commit()
    return report


@router.get("/supplier-balances")
def supplier_balance_report(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id, organization_id = _resolve_report_scope(db, current_user, station_id, organization_id)
    report = build_supplier_balance_report(db, station_id, organization_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.supplier_balances",
        entity_type="report",
        station_id=station_id,
        details={"organization_id": organization_id},
    )
    db.commit()
    return report


@router.get("/tanker-profit")
def tanker_profit_report(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id, organization_id = _resolve_report_scope(db, current_user, station_id, organization_id)
    report = build_tanker_profit_report(db, station_id, from_date, to_date, organization_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.tanker_profit",
        entity_type="report",
        station_id=station_id,
        details={
            "from_date": str(from_date) if from_date else None,
            "to_date": str(to_date) if to_date else None,
            "organization_id": organization_id,
        },
    )
    db.commit()
    return report


@router.get("/tanker-deliveries")
def tanker_delivery_report(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id, organization_id = _resolve_report_scope(db, current_user, station_id, organization_id)
    report = build_tanker_delivery_report(db, station_id, from_date, to_date, organization_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.tanker_deliveries",
        entity_type="report",
        station_id=station_id,
        details={
            "from_date": str(from_date) if from_date else None,
            "to_date": str(to_date) if to_date else None,
            "organization_id": organization_id,
        },
    )
    db.commit()
    return report


@router.get("/tanker-expenses")
def tanker_expense_report(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id, organization_id = _resolve_report_scope(db, current_user, station_id, organization_id)
    report = build_tanker_expense_report(db, station_id, from_date, to_date, organization_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.tanker_expenses",
        entity_type="report",
        station_id=station_id,
        details={
            "from_date": str(from_date) if from_date else None,
            "to_date": str(to_date) if to_date else None,
            "organization_id": organization_id,
        },
    )
    db.commit()
    return report
