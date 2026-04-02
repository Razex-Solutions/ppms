from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.models.fuel_sale import FuelSale
from app.models.expense import Expense
from app.schemas.accounting import ProfitSummaryResponse

router = APIRouter(prefix="/accounting", tags=["Accounting"])


@router.get("/profit-summary", response_model=ProfitSummaryResponse)
def profit_summary(db: Session = Depends(get_db)):
    total_cash_sales = db.query(func.sum(FuelSale.total_amount)).filter(
        FuelSale.sale_type == "cash",
        FuelSale.is_reversed.is_(False)
    ).scalar() or 0.0
    total_credit_sales = db.query(func.sum(FuelSale.total_amount)).filter(
        FuelSale.sale_type == "credit",
        FuelSale.is_reversed.is_(False)
    ).scalar() or 0.0
    total_expenses = db.query(func.sum(Expense.amount)).scalar() or 0.0

    total_sales = total_cash_sales + total_credit_sales
    net_profit = total_sales - total_expenses

    return ProfitSummaryResponse(
        total_cash_sales=total_cash_sales,
        total_credit_sales=total_credit_sales,
        total_sales=total_sales,
        total_expenses=total_expenses,
        net_profit=net_profit
    )
