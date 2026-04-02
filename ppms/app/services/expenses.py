from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.expense import Expense
from app.models.station import Station
from app.models.user import User
from app.schemas.expense import ExpenseCreate, ExpenseUpdate
from app.services.audit import log_audit_event


def create_expense(db: Session, data: ExpenseCreate, current_user: User) -> Expense:
    if current_user.role.name != "Admin" and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Expense amount must be greater than 0")
    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    expense = Expense(
        title=data.title,
        category=data.category,
        amount=data.amount,
        notes=data.notes,
        station_id=data.station_id,
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
        details={"title": expense.title, "amount": expense.amount, "category": expense.category},
    )
    db.commit()
    db.refresh(expense)
    return expense


def update_expense(expense: Expense, data: ExpenseUpdate, db: Session, current_user: User | None = None) -> Expense:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(expense, field, value)
    log_audit_event(
        db,
        current_user=current_user,
        module="expenses",
        action="expenses.update",
        entity_type="expense",
        entity_id=expense.id,
        station_id=expense.station_id,
        details=data.model_dump(exclude_unset=True),
    )
    db.commit()
    db.refresh(expense)
    return expense
