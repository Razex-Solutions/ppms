from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.expense import Expense
from app.models.station import Station
from app.models.user import User
from app.schemas.expense import ExpenseApprovalRequest, ExpenseCreate, ExpenseResponse, ExpenseUpdate
from app.services.audit import log_audit_event
from app.services.expenses import approve_expense as approve_expense_service
from app.services.expenses import create_expense as create_expense_service
from app.services.expenses import ensure_expense_read_access
from app.services.expenses import reject_expense as reject_expense_service
from app.services.expenses import update_expense as update_expense_service

router = APIRouter(prefix="/expenses", tags=["Expenses"])


@router.post("/", response_model=ExpenseResponse)
def create_expense(
    data: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_permission(current_user, "expenses", "create", detail="You do not have permission to create expenses")
    return create_expense_service(db, data, current_user)


@router.get("/", response_model=list[ExpenseResponse])
def list_expenses(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    category: str | None = Query(None),
    status: str | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    q = db.query(Expense)
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        if station_id is not None and organization_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Station does not belong to the requested organization")
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        q = q.join(Station, Station.id == Expense.station_id).filter(Station.organization_id == organization_id)
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Not authorized for this station")
            q = q.filter(Expense.station_id == station_id)
    else:
        station_id = current_user.station_id

    if station_id:
        q = q.filter(Expense.station_id == station_id)
    elif organization_id and (current_user.role.name == "Admin" or is_master_admin(current_user)):
        q = q.join(Station, Station.id == Expense.station_id).filter(Station.organization_id == organization_id)
    if category:
        q = q.filter(Expense.category == category)
    if status:
        q = q.filter(Expense.status == status)
    if from_date:
        q = q.filter(Expense.created_at >= from_date)
    if to_date:
        q = q.filter(Expense.created_at < to_date)
    return q.order_by(Expense.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{expense_id}", response_model=ExpenseResponse)
def get_expense(
    expense_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    expense = db.query(Expense).filter(Expense.id == expense_id).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    ensure_expense_read_access(db, expense, current_user)
    return expense


@router.put("/{expense_id}", response_model=ExpenseResponse)
def update_expense(
    expense_id: int,
    data: ExpenseUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    expense = db.query(Expense).filter(Expense.id == expense_id).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    require_station_access(current_user, expense.station_id, detail="Not authorized for this expense")
    require_permission(current_user, "expenses", "update", detail="You do not have permission to update expenses")
    return update_expense_service(expense, data, db, current_user)


@router.delete("/{expense_id}")
def delete_expense(
    expense_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    expense = db.query(Expense).filter(Expense.id == expense_id).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    require_station_access(current_user, expense.station_id, detail="Not authorized for this expense")
    require_permission(current_user, "expenses", "delete", detail="You do not have permission to delete expenses")
    if expense.status != "pending":
        raise HTTPException(status_code=400, detail="Only pending expenses can be deleted")
    log_audit_event(
        db,
        current_user=current_user,
        module="expenses",
        action="expenses.delete",
        entity_type="expense",
        entity_id=expense.id,
        station_id=expense.station_id,
        details={"title": expense.title, "amount": expense.amount},
    )
    db.delete(expense)
    db.commit()
    return {"message": "Expense deleted"}


@router.post("/{expense_id}/approve", response_model=ExpenseResponse)
def approve_expense(
    expense_id: int,
    data: ExpenseApprovalRequest | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "expenses", "approve", detail="You do not have permission to approve expenses")
    expense = db.query(Expense).filter(Expense.id == expense_id).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return approve_expense_service(expense, db, current_user, data.reason if data else None)


@router.post("/{expense_id}/reject", response_model=ExpenseResponse)
def reject_expense(
    expense_id: int,
    data: ExpenseApprovalRequest | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "expenses", "reject", detail="You do not have permission to reject expenses")
    expense = db.query(Expense).filter(Expense.id == expense_id).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return reject_expense_service(expense, db, current_user, data.reason if data else None)
