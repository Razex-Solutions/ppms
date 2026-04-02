from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.expense import Expense
from app.models.user import User
from app.schemas.expense import ExpenseCreate, ExpenseUpdate, ExpenseResponse
from app.services.expenses import create_expense as create_expense_service
from app.services.expenses import update_expense as update_expense_service

router = APIRouter(prefix="/expenses", tags=["Expenses"])


@router.post("/", response_model=ExpenseResponse)
def create_expense(
    data: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return create_expense_service(db, data, current_user)


@router.get("/", response_model=list[ExpenseResponse])
def list_expenses(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    category: str | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(Expense)
    if station_id:
        q = q.filter(Expense.station_id == station_id)
    if category:
        q = q.filter(Expense.category == category)
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
    require_station_access(current_user, expense.station_id, detail="Not authorized for this expense")
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
    return update_expense_service(expense, data, db)


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
    db.delete(expense)
    db.commit()
    return {"message": "Expense deleted"}
