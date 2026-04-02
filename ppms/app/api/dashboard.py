from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.customer import Customer
from app.models.expense import Expense
from app.models.fuel_sale import FuelSale
from app.models.purchase import Purchase
from app.models.station import Station
from app.models.supplier_payment import SupplierPayment
from app.models.tank import Tank
from app.models.tanker_delivery import TankerDelivery
from app.models.tanker_trip import TankerTrip
from app.models.tanker_trip_expense import TankerTripExpense

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/")
def get_dashboard(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    if current_user.role.name == "Admin":
        if station_id is not None and organization_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Station does not belong to the requested organization")
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        if organization_id is None:
            raise HTTPException(status_code=403, detail="Head office user must belong to an organization")
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Not authorized for this station")
    else:
        station_id = current_user.station_id
        organization_id = get_user_organization_id(current_user)

    # ---------------- SALES ----------------
    sales_q = db.query(func.sum(FuelSale.total_amount)).filter(FuelSale.is_reversed.is_(False))
    if station_id:
        sales_q = sales_q.filter(FuelSale.station_id == station_id)
    elif organization_id:
        sales_q = sales_q.join(Station, Station.id == FuelSale.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        sales_q = sales_q.filter(FuelSale.created_at >= from_date)
    if to_date:
        sales_q = sales_q.filter(FuelSale.created_at < to_date)
    total_sales = sales_q.scalar() or 0

    cash_q = db.query(func.sum(FuelSale.total_amount)).filter(
        FuelSale.sale_type == "cash",
        FuelSale.is_reversed.is_(False)
    )
    if station_id:
        cash_q = cash_q.filter(FuelSale.station_id == station_id)
    elif organization_id:
        cash_q = cash_q.join(Station, Station.id == FuelSale.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        cash_q = cash_q.filter(FuelSale.created_at >= from_date)
    if to_date:
        cash_q = cash_q.filter(FuelSale.created_at < to_date)
    cash_sales = cash_q.scalar() or 0

    credit_q = db.query(func.sum(FuelSale.total_amount)).filter(
        FuelSale.sale_type == "credit",
        FuelSale.is_reversed.is_(False)
    )
    if station_id:
        credit_q = credit_q.filter(FuelSale.station_id == station_id)
    elif organization_id:
        credit_q = credit_q.join(Station, Station.id == FuelSale.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        credit_q = credit_q.filter(FuelSale.created_at >= from_date)
    if to_date:
        credit_q = credit_q.filter(FuelSale.created_at < to_date)
    credit_sales = credit_q.scalar() or 0

    sale_count_q = db.query(func.count(FuelSale.id)).filter(FuelSale.is_reversed.is_(False))
    if station_id:
        sale_count_q = sale_count_q.filter(FuelSale.station_id == station_id)
    elif organization_id:
        sale_count_q = sale_count_q.join(Station, Station.id == FuelSale.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        sale_count_q = sale_count_q.filter(FuelSale.created_at >= from_date)
    if to_date:
        sale_count_q = sale_count_q.filter(FuelSale.created_at < to_date)
    sale_count = sale_count_q.scalar() or 0

    # ---------------- EXPENSES ----------------
    exp_q = db.query(func.sum(Expense.amount)).filter(Expense.status == "approved")
    if station_id:
        exp_q = exp_q.filter(Expense.station_id == station_id)
    elif organization_id:
        exp_q = exp_q.join(Station, Station.id == Expense.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        exp_q = exp_q.filter(Expense.created_at >= from_date)
    if to_date:
        exp_q = exp_q.filter(Expense.created_at < to_date)
    total_expenses = exp_q.scalar() or 0

    # ---------------- PROFIT ----------------
    net_profit = total_sales - total_expenses

    # ---------------- STOCK ----------------
    stock_q = db.query(func.sum(Tank.current_volume))
    if station_id:
        stock_q = stock_q.filter(Tank.station_id == station_id)
    elif organization_id:
        stock_q = stock_q.join(Station, Station.id == Tank.station_id).filter(Station.organization_id == organization_id)
    total_fuel_stock = stock_q.scalar() or 0

    # ---------------- RECEIVABLES ----------------
    recv_q = db.query(func.sum(Customer.outstanding_balance))
    if station_id:
        recv_q = recv_q.filter(Customer.station_id == station_id)
    elif organization_id:
        recv_q = recv_q.join(Station, Station.id == Customer.station_id).filter(Station.organization_id == organization_id)
    total_receivables = recv_q.scalar() or 0

    # ---------------- PAYABLES ----------------
    purchase_payables_q = db.query(func.sum(Purchase.total_amount)).join(Tank, Purchase.tank_id == Tank.id).filter(
        Purchase.status == "approved",
        Purchase.is_reversed.is_(False)
    )
    if station_id:
        purchase_payables_q = purchase_payables_q.filter(Tank.station_id == station_id)
    elif organization_id:
        purchase_payables_q = purchase_payables_q.join(Station, Station.id == Tank.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        purchase_payables_q = purchase_payables_q.filter(Purchase.created_at >= from_date)
    if to_date:
        purchase_payables_q = purchase_payables_q.filter(Purchase.created_at < to_date)
    total_purchase_payables = purchase_payables_q.scalar() or 0

    supplier_payments_q = db.query(func.sum(SupplierPayment.amount)).filter(SupplierPayment.is_reversed.is_(False))
    if station_id:
        supplier_payments_q = supplier_payments_q.filter(SupplierPayment.station_id == station_id)
    elif organization_id:
        supplier_payments_q = supplier_payments_q.join(Station, Station.id == SupplierPayment.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        supplier_payments_q = supplier_payments_q.filter(SupplierPayment.created_at >= from_date)
    if to_date:
        supplier_payments_q = supplier_payments_q.filter(SupplierPayment.created_at < to_date)
    total_supplier_payments = supplier_payments_q.scalar() or 0

    total_payables = max(total_purchase_payables - total_supplier_payments, 0)

    # ---------------- LOW STOCK ALERTS ----------------
    low_stock_tanks_q = db.query(Tank).filter(Tank.current_volume <= Tank.low_stock_threshold)
    if station_id:
        low_stock_tanks_q = low_stock_tanks_q.filter(Tank.station_id == station_id)
    elif organization_id:
        low_stock_tanks_q = low_stock_tanks_q.join(Station, Station.id == Tank.station_id).filter(Station.organization_id == organization_id)
    low_stock_tanks = low_stock_tanks_q.all()
    alerts = [
        {
            "tank_id": t.id,
            "tank_name": t.name,
            "current_volume": round(t.current_volume, 2),
            "threshold": t.low_stock_threshold,
            "fuel_type": t.fuel_type.name if t.fuel_type else "Unknown"
        }
        for t in low_stock_tanks
    ]

    # ---------------- CREDIT LIMIT ALERTS ----------------
    credit_limit_customers_q = db.query(Customer).filter(
        Customer.credit_limit > 0,
        Customer.outstanding_balance >= (Customer.credit_limit * 0.9)
    )
    if station_id:
        credit_limit_customers_q = credit_limit_customers_q.filter(Customer.station_id == station_id)
    elif organization_id:
        credit_limit_customers_q = credit_limit_customers_q.join(Station, Station.id == Customer.station_id).filter(Station.organization_id == organization_id)
    credit_limit_customers = credit_limit_customers_q.all()
    credit_alerts = [
        {
            "customer_id": c.id,
            "customer_name": c.name,
            "outstanding_balance": round(c.outstanding_balance, 2),
            "credit_limit": c.credit_limit,
            "usage_percentage": round((c.outstanding_balance / c.credit_limit) * 100, 2)
        }
        for c in credit_limit_customers
    ]

    tanker_trips_q = db.query(func.count(TankerTrip.id)).filter(TankerTrip.status == "completed")
    if station_id:
        tanker_trips_q = tanker_trips_q.filter(TankerTrip.station_id == station_id)
    elif organization_id:
        tanker_trips_q = tanker_trips_q.join(Station, Station.id == TankerTrip.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        tanker_trips_q = tanker_trips_q.filter(TankerTrip.completed_at >= from_date)
    if to_date:
        tanker_trips_q = tanker_trips_q.filter(TankerTrip.completed_at < to_date)
    tanker_trip_count = tanker_trips_q.scalar() or 0

    tanker_profit_q = db.query(
        func.sum(TankerTrip.fuel_revenue),
        func.sum(TankerTrip.delivery_revenue),
        func.sum(TankerTrip.expense_total),
        func.sum(TankerTrip.net_profit),
    ).filter(TankerTrip.status == "completed")
    if station_id:
        tanker_profit_q = tanker_profit_q.filter(TankerTrip.station_id == station_id)
    elif organization_id:
        tanker_profit_q = tanker_profit_q.join(Station, Station.id == TankerTrip.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        tanker_profit_q = tanker_profit_q.filter(TankerTrip.completed_at >= from_date)
    if to_date:
        tanker_profit_q = tanker_profit_q.filter(TankerTrip.completed_at < to_date)
    tanker_fuel_revenue, tanker_delivery_revenue, tanker_expense_total, tanker_net_profit = tanker_profit_q.one()

    tanker_credit_q = db.query(func.sum(TankerDelivery.outstanding_amount)).join(TankerTrip, TankerTrip.id == TankerDelivery.trip_id)
    if station_id:
        tanker_credit_q = tanker_credit_q.filter(TankerTrip.station_id == station_id)
    elif organization_id:
        tanker_credit_q = tanker_credit_q.join(Station, Station.id == TankerTrip.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        tanker_credit_q = tanker_credit_q.filter(TankerDelivery.created_at >= from_date)
    if to_date:
        tanker_credit_q = tanker_credit_q.filter(TankerDelivery.created_at < to_date)
    tanker_credit_outstanding = tanker_credit_q.scalar() or 0

    tanker_expense_breakdown_q = db.query(
        TankerTripExpense.expense_type,
        func.sum(TankerTripExpense.amount),
    ).join(TankerTrip, TankerTrip.id == TankerTripExpense.trip_id)
    if station_id:
        tanker_expense_breakdown_q = tanker_expense_breakdown_q.filter(TankerTrip.station_id == station_id)
    elif organization_id:
        tanker_expense_breakdown_q = tanker_expense_breakdown_q.join(Station, Station.id == TankerTrip.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        tanker_expense_breakdown_q = tanker_expense_breakdown_q.filter(TankerTripExpense.created_at >= from_date)
    if to_date:
        tanker_expense_breakdown_q = tanker_expense_breakdown_q.filter(TankerTripExpense.created_at < to_date)
    tanker_expense_breakdown_rows = tanker_expense_breakdown_q.group_by(TankerTripExpense.expense_type).all()
    tanker_expense_breakdown = {
        expense_type: round(amount or 0, 2) for expense_type, amount in tanker_expense_breakdown_rows
    }

    return {
        "filters": {
            "station_id": station_id,
            "organization_id": organization_id,
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
        "tanker": {
            "completed_trips": tanker_trip_count,
            "fuel_revenue": round(tanker_fuel_revenue or 0, 2),
            "delivery_revenue": round(tanker_delivery_revenue or 0, 2),
            "total_expenses": round(tanker_expense_total or 0, 2),
            "net_profit": round(tanker_net_profit or 0, 2),
            "credit_outstanding": round(tanker_credit_outstanding or 0, 2),
            "expense_breakdown": tanker_expense_breakdown,
        },
        "low_stock_alerts": alerts,
        "credit_limit_alerts": credit_alerts,
    }
