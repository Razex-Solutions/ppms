from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.user import User
from app.services.audit import log_audit_event
from app.services.reports import (
    build_customer_balance_report,
    build_daily_closing_report,
    build_shift_variance_report,
    build_stock_movement_report,
    build_supplier_balance_report,
)

router = APIRouter(prefix="/reports", tags=["Reports"])


def _resolve_station_id(current_user: User, station_id: int | None) -> int | None:
    if current_user.role.name != "Admin":
        return current_user.station_id
    return station_id


@router.get("/daily-closing")
def daily_closing_report(
    report_date: date = Query(...),
    station_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id = _resolve_station_id(current_user, station_id)
    report = build_daily_closing_report(db, station_id, report_date)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.daily_closing",
        entity_type="report",
        station_id=station_id,
        details={"report_date": str(report_date)},
    )
    db.commit()
    return report


@router.get("/shift-variance")
def shift_variance_report(
    station_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id = _resolve_station_id(current_user, station_id)
    report = build_shift_variance_report(db, station_id, from_date, to_date)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.shift_variance",
        entity_type="report",
        station_id=station_id,
        details={"from_date": str(from_date) if from_date else None, "to_date": str(to_date) if to_date else None},
    )
    db.commit()
    return report


@router.get("/stock-movement")
def stock_movement_report(
    station_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id = _resolve_station_id(current_user, station_id)
    report = build_stock_movement_report(db, station_id, from_date, to_date)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.stock_movement",
        entity_type="report",
        station_id=station_id,
        details={"from_date": str(from_date) if from_date else None, "to_date": str(to_date) if to_date else None},
    )
    db.commit()
    return report


@router.get("/customer-balances")
def customer_balance_report(
    station_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id = _resolve_station_id(current_user, station_id)
    report = build_customer_balance_report(db, station_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.customer_balances",
        entity_type="report",
        station_id=station_id,
    )
    db.commit()
    return report


@router.get("/supplier-balances")
def supplier_balance_report(
    station_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view reports")
    station_id = _resolve_station_id(current_user, station_id)
    report = build_supplier_balance_report(db, station_id)
    log_audit_event(
        db,
        current_user=current_user,
        module="reports",
        action="reports.supplier_balances",
        entity_type="report",
        station_id=station_id,
    )
    db.commit()
    return report
