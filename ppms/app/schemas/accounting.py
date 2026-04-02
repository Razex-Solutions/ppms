from pydantic import BaseModel


class ProfitSummaryResponse(BaseModel):
    total_cash_sales: float
    total_credit_sales: float
    total_sales: float
    total_expenses: float
    net_profit: float