from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.time import utc_now
from app.models.expense import Expense
from app.models.station import Station
from app.models.user import User
from app.schemas.expense import ExpenseCreate, ExpenseUpdate
from app.services.audit import log_audit_event
from app.services.notifications import notify_approval_requested, notify_decision


def _get_station(db: Session, station_id: int) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    return station


def _ensure_expense_read_access(db: Session, expense: Expense, current_user: User) -> None:
    station = _get_station(db, expense.station_id)
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return
    if is_head_office_user(current_user):
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this expense")
        return
    if current_user.station_id != expense.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this expense")


def _ensure_expense_approval_access(db: Session, expense: Expense, current_user: User) -> None:
    station = _get_station(db, expense.station_id)
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return
    if is_head_office_user(current_user) and station.organization_id == get_user_organization_id(current_user):
        return
    raise HTTPException(status_code=403, detail="You do not have permission to approve expenses")


def create_expense(db: Session, data: ExpenseCreate, current_user: User) -> Expense:
    station = _get_station(db, data.station_id)
    if current_user.role.name != "Admin" and not is_master_admin(current_user) and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Expense amount must be greater than 0")

    is_auto_approved = current_user.role.name == "Admin" or is_master_admin(current_user)
    expense = Expense(
        title=data.title,
        category=data.category,
        amount=data.amount,
        notes=data.notes,
        station_id=data.station_id,
        status="approved" if is_auto_approved else "pending",
        submitted_by_user_id=current_user.id,
        approved_by_user_id=current_user.id if is_auto_approved else None,
        approved_at=utc_now() if is_auto_approved else None,
    )
    db.add(expense)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="expenses",
        action="expenses.create",
        entity_type="expense",
        entity_id=expense.id,
        station_id=expense.station_id,
        details={
            "title": expense.title,
            "amount": expense.amount,
            "category": expense.category,
            "status": expense.status,
            "organization_id": station.organization_id,
        },
    )
    if not is_auto_approved:
        notify_approval_requested(
            db,
            actor_user=current_user,
            station_id=expense.station_id,
            organization_id=station.organization_id,
            entity_type="expense",
            entity_id=expense.id,
            title="Expense approval requested",
            message=f"{current_user.full_name} submitted expense '{expense.title}' for approval.",
            event_type="expense.pending_approval",
        )
    db.commit()
    db.refresh(expense)
    return expense


def update_expense(expense: Expense, data: ExpenseUpdate, db: Session, current_user: User | None = None) -> Expense:
    if expense.status != "pending":
        raise HTTPException(status_code=400, detail="Only pending expenses can be updated")
    updates = data.model_dump(exclude_unset=True)
    if "amount" in updates and updates["amount"] is not None and updates["amount"] <= 0:
        raise HTTPException(status_code=400, detail="Expense amount must be greater than 0")
    for field, value in updates.items():
        setattr(expense, field, value)
    expense.rejected_at = None
    expense.rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="expenses",
        action="expenses.update",
        entity_type="expense",
        entity_id=expense.id,
        station_id=expense.station_id,
        details=updates,
    )
    db.commit()
    db.refresh(expense)
    return expense


def approve_expense(expense: Expense, db: Session, current_user: User, reason: str | None = None) -> Expense:
    if expense.status == "approved":
        raise HTTPException(status_code=400, detail="Expense is already approved")
    _ensure_expense_approval_access(db, expense, current_user)
    expense.status = "approved"
    expense.approved_by_user_id = current_user.id
    expense.approved_at = utc_now()
    expense.rejected_at = None
    expense.rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="expenses",
        action="expenses.approve",
        entity_type="expense",
        entity_id=expense.id,
        station_id=expense.station_id,
        details={"reason": reason},
    )
    notify_decision(
        db,
        recipient_user_id=expense.submitted_by_user_id,
        actor_user=current_user,
        station_id=expense.station_id,
        organization_id=_get_station(db, expense.station_id).organization_id,
        entity_type="expense",
        entity_id=expense.id,
        title="Expense approved",
        message=f"Expense '{expense.title}' was approved.",
        event_type="expense.approved",
    )
    db.commit()
    db.refresh(expense)
    return expense


def reject_expense(expense: Expense, db: Session, current_user: User, reason: str | None = None) -> Expense:
    if expense.status == "approved":
        raise HTTPException(status_code=400, detail="Approved expenses cannot be rejected")
    _ensure_expense_approval_access(db, expense, current_user)
    expense.status = "rejected"
    expense.approved_by_user_id = None
    expense.approved_at = None
    expense.rejected_at = utc_now()
    expense.rejection_reason = reason
    log_audit_event(
        db,
        current_user=current_user,
        module="expenses",
        action="expenses.reject",
        entity_type="expense",
        entity_id=expense.id,
        station_id=expense.station_id,
        details={"reason": reason},
    )
    notify_decision(
        db,
        recipient_user_id=expense.submitted_by_user_id,
        actor_user=current_user,
        station_id=expense.station_id,
        organization_id=_get_station(db, expense.station_id).organization_id,
        entity_type="expense",
        entity_id=expense.id,
        title="Expense rejected",
        message=f"Expense '{expense.title}' was rejected.",
        event_type="expense.rejected",
    )
    db.commit()
    db.refresh(expense)
    return expense


def ensure_expense_read_access(db: Session, expense: Expense, current_user: User) -> None:
    _ensure_expense_read_access(db, expense, current_user)
