from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.customer import Customer
from app.models.expense import Expense
from app.models.notification import Notification
from app.models.payroll_run import PayrollRun
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.user import User
from app.schemas.accounting import AccountantAlertItem, AccountantWorkspaceSummaryResponse, ProfitSummaryResponse
from app.services.audit import log_audit_event
from app.services.reports import build_profit_summary

router = APIRouter(prefix="/accounting", tags=["Accounting"])


def _resolve_profit_scope(
    db: Session,
    current_user: User,
    station_id: int | None,
    organization_id: int | None,
) -> tuple[int | None, int | None]:
    if is_master_admin(current_user):
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


@router.get("/profit-summary", response_model=ProfitSummaryResponse)
def profit_summary(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view profit summaries")
    station_id, organization_id = _resolve_profit_scope(
        db,
        current_user,
        station_id,
        organization_id,
    )
    summary = build_profit_summary(
        db,
        station_id=station_id,
        organization_id=organization_id,
        from_date=from_date,
        to_date=to_date,
    )
    log_audit_event(
        db,
        current_user=current_user,
        module="accounting",
        action="accounting.profit_summary",
        entity_type="report",
        station_id=station_id,
        details={
            "organization_id": organization_id,
            "from_date": str(from_date) if from_date else None,
            "to_date": str(to_date) if to_date else None,
        },
    )
    db.commit()
    return ProfitSummaryResponse(**summary)


@router.get("/workspace-summary", response_model=AccountantWorkspaceSummaryResponse)
def accountant_workspace_summary(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "ledger", "read", detail="You do not have permission to view accounting workspace")
    station_id, organization_id = _resolve_profit_scope(db, current_user, station_id, organization_id)

    overdue_customers_q = db.query(Customer).filter(Customer.outstanding_balance > 0)
    if station_id is not None:
        overdue_customers_q = overdue_customers_q.filter(Customer.station_id == station_id)
    elif organization_id is not None:
        overdue_customers_q = overdue_customers_q.join(Station, Station.id == Customer.station_id).filter(Station.organization_id == organization_id)
    overdue_customers = overdue_customers_q.order_by(Customer.outstanding_balance.desc(), Customer.id.asc()).all()

    supplier_dues_q = db.query(Supplier).filter(Supplier.payable_balance > 0)
    supplier_dues = supplier_dues_q.order_by(Supplier.payable_balance.desc(), Supplier.id.asc()).all()

    expense_scope_q = db.query(Expense).filter(Expense.status == "approved")
    if station_id is not None:
        expense_scope_q = expense_scope_q.filter(Expense.station_id == station_id)
    elif organization_id is not None:
        expense_scope_q = expense_scope_q.join(Station, Station.id == Expense.station_id).filter(Station.organization_id == organization_id)
    average_expense = expense_scope_q.with_entities(func.avg(Expense.amount)).scalar() or 0.0
    unusual_expense_cutoff = max(float(average_expense) * 2, 10000.0)
    unusual_expenses = (
        expense_scope_q.filter(Expense.amount >= unusual_expense_cutoff)
        .order_by(Expense.amount.desc(), Expense.id.desc())
        .all()
    )

    payroll_q = db.query(PayrollRun).filter(PayrollRun.status == "draft")
    if station_id is not None:
        payroll_q = payroll_q.filter(PayrollRun.station_id == station_id)
    elif organization_id is not None:
        payroll_q = payroll_q.join(Station, Station.id == PayrollRun.station_id).filter(Station.organization_id == organization_id)
    draft_payrolls = payroll_q.order_by(PayrollRun.created_at.desc(), PayrollRun.id.desc()).all()

    notifications_q = db.query(Notification).filter(
        Notification.recipient_user_id == current_user.id,
        Notification.is_read.is_(False),
    )
    unread_notification_count = notifications_q.count()

    alerts: list[AccountantAlertItem] = []
    for customer in overdue_customers[:5]:
        alerts.append(
            AccountantAlertItem(
                kind="customer_due",
                entity_id=customer.id,
                title=f"Customer overdue: {customer.name}",
                detail="Outstanding customer balance needs follow-up.",
                amount=round(customer.outstanding_balance or 0.0, 2),
            )
        )
    for supplier in supplier_dues[:5]:
        alerts.append(
            AccountantAlertItem(
                kind="supplier_due",
                entity_id=supplier.id,
                title=f"Supplier due: {supplier.name}",
                detail="Supplier payable balance is outstanding.",
                amount=round(supplier.payable_balance or 0.0, 2),
            )
        )
    for expense in unusual_expenses[:5]:
        alerts.append(
            AccountantAlertItem(
                kind="unusual_expense",
                entity_id=expense.id,
                title=f"High expense: {expense.title}",
                detail=f"Expense is above the unusual threshold of {round(unusual_expense_cutoff, 2)}.",
                amount=round(expense.amount or 0.0, 2),
            )
        )
    for payroll_run in draft_payrolls[:5]:
        alerts.append(
            AccountantAlertItem(
                kind="payroll_issue",
                entity_id=payroll_run.id,
                title=f"Draft payroll run #{payroll_run.id}",
                detail="Payroll run is still pending finalization.",
                amount=round(payroll_run.total_net_amount or 0.0, 2),
            )
        )

    return AccountantWorkspaceSummaryResponse(
        station_id=station_id,
        organization_id=organization_id,
        overdue_customer_count=len(overdue_customers),
        overdue_customer_total=round(sum(customer.outstanding_balance or 0.0 for customer in overdue_customers), 2),
        supplier_due_count=len(supplier_dues),
        supplier_due_total=round(sum(supplier.payable_balance or 0.0 for supplier in supplier_dues), 2),
        unusual_expense_count=len(unusual_expenses),
        unusual_expense_total=round(sum(expense.amount or 0.0 for expense in unusual_expenses), 2),
        draft_payroll_count=len(draft_payrolls),
        pending_payroll_total=round(sum(item.total_net_amount or 0.0 for item in draft_payrolls), 2),
        unread_notification_count=unread_notification_count,
        alerts=alerts,
    )
