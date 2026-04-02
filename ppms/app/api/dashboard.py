from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.core.dependencies import get_current_user

from app.models.fuel_sale import FuelSale
from app.models.expense import Expense
from app.models.tank import Tank
from app.models.customer import Customer
from app.models.purchase import Purchase
from app.models.supplier_payment import SupplierPayment

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/")
def get_dashboard(
    station_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    def apply_filters(q, model):
        if station_id:
            q = q.filter(model.station_id == station_id)
        if from_date:
            q = q.filter(model.created_at >= from_date)
        if to_date:
            q = q.filter(model.created_at < to_date)
        return q

    # ---------------- SALES ----------------
    sales_q = apply_filters(
        db.query(func.sum(FuelSale.total_amount)).filter(FuelSale.is_reversed.is_(False)),
        FuelSale
    )
    total_sales = sales_q.scalar() or 0

    cash_q = apply_filters(
        db.query(func.sum(FuelSale.total_amount)).filter(
            FuelSale.sale_type == "cash",
            FuelSale.is_reversed.is_(False)
        ),
        FuelSale
    )
    cash_sales = cash_q.scalar() or 0

    credit_q = apply_filters(
        db.query(func.sum(FuelSale.total_amount)).filter(
            FuelSale.sale_type == "credit",
            FuelSale.is_reversed.is_(False)
        ),
        FuelSale
    )
    credit_sales = credit_q.scalar() or 0

    sale_count = apply_filters(
        db.query(func.count(FuelSale.id)).filter(FuelSale.is_reversed.is_(False)),
        FuelSale
    ).scalar() or 0

    # ---------------- EXPENSES ----------------
    exp_q = apply_filters(db.query(func.sum(Expense.amount)), Expense)
    total_expenses = exp_q.scalar() or 0

    # ---------------- PROFIT ----------------
    net_profit = total_sales - total_expenses

    # ---------------- STOCK ----------------
    stock_q = db.query(func.sum(Tank.current_volume))
    if station_id:
        stock_q = stock_q.filter(Tank.station_id == station_id)
    total_fuel_stock = stock_q.scalar() or 0

    # ---------------- RECEIVABLES ----------------
    recv_q = db.query(func.sum(Customer.outstanding_balance))
    if station_id:
        recv_q = recv_q.filter(Customer.station_id == station_id)
    total_receivables = recv_q.scalar() or 0

    # ---------------- PAYABLES ----------------
    purchase_payables_q = db.query(func.sum(Purchase.total_amount)).join(Tank, Purchase.tank_id == Tank.id).filter(
        Purchase.is_reversed.is_(False)
    )
    if station_id:
        purchase_payables_q = purchase_payables_q.filter(Tank.station_id == station_id)
    if from_date:
        purchase_payables_q = purchase_payables_q.filter(Purchase.created_at >= from_date)
    if to_date:
        purchase_payables_q = purchase_payables_q.filter(Purchase.created_at < to_date)
    total_purchase_payables = purchase_payables_q.scalar() or 0

    supplier_payments_q = db.query(func.sum(SupplierPayment.amount)).filter(SupplierPayment.is_reversed.is_(False))
    if station_id:
        supplier_payments_q = supplier_payments_q.filter(SupplierPayment.station_id == station_id)
    if from_date:
        supplier_payments_q = supplier_payments_q.filter(SupplierPayment.created_at >= from_date)
    if to_date:
        supplier_payments_q = supplier_payments_q.filter(SupplierPayment.created_at < to_date)
    total_supplier_payments = supplier_payments_q.scalar() or 0

    total_payables = max(total_purchase_payables - total_supplier_payments, 0)

    # ---------------- LOW STOCK ALERTS ----------------
    low_stock_tanks = db.query(Tank).filter(Tank.current_volume <= Tank.low_stock_threshold).all()
    alerts = [
        {
            "tank_id": t.id,
            "tank_name": t.name,
            "current_volume": round(t.current_volume, 2),
            "threshold": t.low_stock_threshold,
            "fuel_type": t.fuel_type.name if t.fuel_type else "Unknown"
        }
        for t in low_stock_tanks if (not station_id or t.station_id == station_id)
    ]

    # ---------------- CREDIT LIMIT ALERTS ----------------
    credit_limit_customers = db.query(Customer).filter(
        Customer.credit_limit > 0,
        Customer.outstanding_balance >= (Customer.credit_limit * 0.9)
    ).all()
    credit_alerts = [
        {
            "customer_id": c.id,
            "customer_name": c.name,
            "outstanding_balance": round(c.outstanding_balance, 2),
            "credit_limit": c.credit_limit,
            "usage_percentage": round((c.outstanding_balance / c.credit_limit) * 100, 2)
        }
        for c in credit_limit_customers if (not station_id or c.station_id == station_id)
    ]

    return {
        "filters": {
            "station_id": station_id,
            "from_date": str(from_date) if from_date else None,
            "to_date": str(to_date) if to_date else None,
        },
        "sales": {
            "total": round(total_sales, 2),
            "cash": round(cash_sales, 2),
            "credit": round(credit_sales, 2),
            "count": sale_count,
        },
        "expenses": round(total_expenses, 2),
        "net_profit": round(net_profit, 2),
        "fuel_stock_liters": round(total_fuel_stock, 2),
        "receivables": round(total_receivables, 2),
        "payables": round(total_payables, 2),
        "low_stock_alerts": alerts,
        "credit_limit_alerts": credit_alerts,
    }
