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


class AccountantAlertItem(BaseModel):
    kind: str
    entity_id: int | None = None
    title: str
    detail: str
    amount: float | None = None


class AccountantWorkspaceSummaryResponse(BaseModel):
    station_id: int | None = None
    organization_id: int | None = None
    overdue_customer_count: int
    overdue_customer_total: float
    supplier_due_count: int
    supplier_due_total: float
    unusual_expense_count: int
    unusual_expense_total: float
    draft_payroll_count: int
    pending_payroll_total: float
    unread_notification_count: int
    alerts: list[AccountantAlertItem]
