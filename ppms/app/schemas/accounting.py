from pydantic import BaseModel


class ProfitSummaryResponse(BaseModel):
    station_id: int | None = None
    organization_id: int | None = None
    total_cash_sales: float
    total_credit_sales: float
    total_pos_sales: float
    total_sales: float
    total_purchase_cost: float
    total_expenses: float
    total_internal_fuel_cost: float
    gross_margin: float
    net_profit: float
