from datetime import date, datetime, time, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.customer_payment import CustomerPayment
from app.models.expense import Expense
from app.models.fuel_sale import FuelSale
from app.models.nozzle import Nozzle
from app.models.pos_sale import POSSale
from app.models.purchase import Purchase
from app.models.shift import Shift
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.supplier_payment import SupplierPayment
from app.models.tank import Tank


def _day_bounds(report_date: date) -> tuple[datetime, datetime]:
    start = datetime.combine(report_date, time.min)
    end = start + timedelta(days=1)
    return start, end


def build_daily_closing_report(
    db: Session,
    station_id: int | None,
    report_date: date,
    organization_id: int | None = None,
) -> dict:
    start, end = _day_bounds(report_date)

    fuel_cash_sales_query = db.query(func.sum(FuelSale.total_amount)).filter(
        FuelSale.sale_type == "cash",
        FuelSale.is_reversed.is_(False),
        FuelSale.created_at >= start,
        FuelSale.created_at < end,
    )
    fuel_credit_sales_query = db.query(func.sum(FuelSale.total_amount)).filter(
        FuelSale.sale_type == "credit",
        FuelSale.is_reversed.is_(False),
        FuelSale.created_at >= start,
        FuelSale.created_at < end,
    )
    pos_cash_sales_query = db.query(func.sum(POSSale.total_amount)).filter(
        POSSale.payment_method == "cash",
        POSSale.is_reversed.is_(False),
        POSSale.created_at >= start,
        POSSale.created_at < end,
    )
    customer_payments_query = db.query(func.sum(CustomerPayment.amount)).filter(
        CustomerPayment.is_reversed.is_(False),
        CustomerPayment.created_at >= start,
        CustomerPayment.created_at < end,
    )
    supplier_payments_query = db.query(func.sum(SupplierPayment.amount)).filter(
        SupplierPayment.is_reversed.is_(False),
        SupplierPayment.created_at >= start,
        SupplierPayment.created_at < end,
    )
    expenses_query = db.query(func.sum(Expense.amount)).filter(
        Expense.created_at >= start,
        Expense.created_at < end,
    )

    if station_id is not None:
        fuel_cash_sales_query = fuel_cash_sales_query.filter(FuelSale.station_id == station_id)
        fuel_credit_sales_query = fuel_credit_sales_query.filter(FuelSale.station_id == station_id)
        pos_cash_sales_query = pos_cash_sales_query.filter(POSSale.station_id == station_id)
        customer_payments_query = customer_payments_query.filter(CustomerPayment.station_id == station_id)
        supplier_payments_query = supplier_payments_query.filter(SupplierPayment.station_id == station_id)
        expenses_query = expenses_query.filter(Expense.station_id == station_id)
    elif organization_id is not None:
        fuel_cash_sales_query = fuel_cash_sales_query.join(Station, Station.id == FuelSale.station_id).filter(Station.organization_id == organization_id)
        fuel_credit_sales_query = fuel_credit_sales_query.join(Station, Station.id == FuelSale.station_id).filter(Station.organization_id == organization_id)
        pos_cash_sales_query = pos_cash_sales_query.join(Station, Station.id == POSSale.station_id).filter(Station.organization_id == organization_id)
        customer_payments_query = customer_payments_query.join(Station, Station.id == CustomerPayment.station_id).filter(Station.organization_id == organization_id)
        supplier_payments_query = supplier_payments_query.join(Station, Station.id == SupplierPayment.station_id).filter(Station.organization_id == organization_id)
        expenses_query = expenses_query.join(Station, Station.id == Expense.station_id).filter(Station.organization_id == organization_id)

    fuel_cash_sales = fuel_cash_sales_query.scalar() or 0.0
    fuel_credit_sales = fuel_credit_sales_query.scalar() or 0.0
    pos_cash_sales = pos_cash_sales_query.scalar() or 0.0
    customer_payments = customer_payments_query.scalar() or 0.0
    supplier_payments = supplier_payments_query.scalar() or 0.0
    expenses = expenses_query.scalar() or 0.0

    cash_inflows = fuel_cash_sales + pos_cash_sales + customer_payments
    cash_outflows = supplier_payments + expenses

    return {
        "report_date": str(report_date),
        "station_id": station_id,
        "organization_id": organization_id,
        "fuel_cash_sales": round(fuel_cash_sales, 2),
        "fuel_credit_sales": round(fuel_credit_sales, 2),
        "pos_cash_sales": round(pos_cash_sales, 2),
        "customer_payments": round(customer_payments, 2),
        "supplier_payments": round(supplier_payments, 2),
        "expenses": round(expenses, 2),
        "cash_inflows": round(cash_inflows, 2),
        "cash_outflows": round(cash_outflows, 2),
        "net_cash_movement": round(cash_inflows - cash_outflows, 2),
    }


def build_shift_variance_report(
    db: Session,
    station_id: int | None,
    from_date: date | None,
    to_date: date | None,
    organization_id: int | None = None,
) -> dict:
    query = db.query(Shift).filter(Shift.status == "closed")
    if station_id is not None:
        query = query.filter(Shift.station_id == station_id)
    elif organization_id is not None:
        query = query.join(Station, Station.id == Shift.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        query = query.filter(Shift.end_time >= from_date)
    if to_date:
        query = query.filter(Shift.end_time < to_date)

    shifts = query.order_by(Shift.end_time.desc()).all()
    items = [
        {
            "shift_id": shift.id,
            "station_id": shift.station_id,
            "user_id": shift.user_id,
            "start_time": shift.start_time,
            "end_time": shift.end_time,
            "initial_cash": round(shift.initial_cash or 0.0, 2),
            "expected_cash": round(shift.expected_cash or 0.0, 2),
            "actual_cash_collected": round(shift.actual_cash_collected or 0.0, 2),
            "difference": round(shift.difference or 0.0, 2),
        }
        for shift in shifts
    ]
    return {
        "station_id": station_id,
        "organization_id": organization_id,
        "count": len(items),
        "total_variance": round(sum(item["difference"] for item in items), 2),
        "items": items,
    }


def build_stock_movement_report(
    db: Session,
    station_id: int | None,
    from_date: date | None,
    to_date: date | None,
    organization_id: int | None = None,
) -> dict:
    tanks_query = db.query(Tank)
    if station_id is not None:
        tanks_query = tanks_query.filter(Tank.station_id == station_id)
    elif organization_id is not None:
        tanks_query = tanks_query.join(Station, Station.id == Tank.station_id).filter(Station.organization_id == organization_id)

    items = []
    for tank in tanks_query.order_by(Tank.id.asc()).all():
        purchases_query = db.query(func.sum(Purchase.quantity)).filter(
            Purchase.tank_id == tank.id,
            Purchase.is_reversed.is_(False),
        )
        sales_query = db.query(func.sum(FuelSale.quantity)).join(Nozzle, Nozzle.id == FuelSale.nozzle_id).filter(
            Nozzle.tank_id == tank.id,
            FuelSale.is_reversed.is_(False),
        )
        if from_date:
            purchases_query = purchases_query.filter(Purchase.created_at >= from_date)
            sales_query = sales_query.filter(FuelSale.created_at >= from_date)
        if to_date:
            purchases_query = purchases_query.filter(Purchase.created_at < to_date)
            sales_query = sales_query.filter(FuelSale.created_at < to_date)

        purchased = purchases_query.scalar() or 0.0
        sold = sales_query.scalar() or 0.0
        items.append(
            {
                "tank_id": tank.id,
                "tank_name": tank.name,
                "station_id": tank.station_id,
                "fuel_type_id": tank.fuel_type_id,
                "purchased_liters": round(purchased, 2),
                "sold_liters": round(sold, 2),
                "net_movement_liters": round(purchased - sold, 2),
                "current_volume_liters": round(tank.current_volume, 2),
            }
        )

    return {"station_id": station_id, "organization_id": organization_id, "count": len(items), "items": items}


def build_customer_balance_report(db: Session, station_id: int | None, organization_id: int | None = None) -> dict:
    query = db.query(Customer)
    if station_id is not None:
        query = query.filter(Customer.station_id == station_id)
    elif organization_id is not None:
        query = query.join(Station, Station.id == Customer.station_id).filter(Station.organization_id == organization_id)
    items = [
        {
            "customer_id": customer.id,
            "customer_name": customer.name,
            "station_id": customer.station_id,
            "credit_limit": round(customer.credit_limit or 0.0, 2),
            "outstanding_balance": round(customer.outstanding_balance or 0.0, 2),
        }
        for customer in query.order_by(Customer.name.asc()).all()
        if (customer.outstanding_balance or 0.0) > 0
    ]
    return {"station_id": station_id, "organization_id": organization_id, "count": len(items), "items": items}


def build_supplier_balance_report(db: Session, station_id: int | None, organization_id: int | None = None) -> dict:
    purchase_balances = db.query(
        Purchase.supplier_id.label("supplier_id"),
        func.sum(Purchase.total_amount).label("purchased_total"),
    ).filter(Purchase.is_reversed.is_(False))
    if station_id is not None:
        purchase_balances = purchase_balances.join(Tank, Tank.id == Purchase.tank_id).filter(Tank.station_id == station_id)
    elif organization_id is not None:
        purchase_balances = purchase_balances.join(Tank, Tank.id == Purchase.tank_id).join(Station, Station.id == Tank.station_id).filter(
            Station.organization_id == organization_id
        )
    purchase_rows = {
        row.supplier_id: row.purchased_total or 0.0
        for row in purchase_balances.group_by(Purchase.supplier_id).all()
    }

    payment_balances = db.query(
        SupplierPayment.supplier_id.label("supplier_id"),
        func.sum(SupplierPayment.amount).label("paid_total"),
    ).filter(SupplierPayment.is_reversed.is_(False))
    if station_id is not None:
        payment_balances = payment_balances.filter(SupplierPayment.station_id == station_id)
    elif organization_id is not None:
        payment_balances = payment_balances.join(Station, Station.id == SupplierPayment.station_id).filter(Station.organization_id == organization_id)
    payment_rows = {
        row.supplier_id: row.paid_total or 0.0
        for row in payment_balances.group_by(SupplierPayment.supplier_id).all()
    }

    supplier_ids = sorted(set(purchase_rows) | set(payment_rows))
    suppliers = {supplier.id: supplier for supplier in db.query(Supplier).filter(Supplier.id.in_(supplier_ids)).all()}
    items = [
        {
            "supplier_id": supplier_id,
            "supplier_name": suppliers[supplier_id].name,
            "station_id": station_id,
            "payable_balance": round((purchase_rows.get(supplier_id, 0.0) - payment_rows.get(supplier_id, 0.0)), 2),
        }
        for supplier_id in supplier_ids
        if suppliers.get(supplier_id) and (purchase_rows.get(supplier_id, 0.0) - payment_rows.get(supplier_id, 0.0)) > 0
    ]
    items.sort(key=lambda item: item["supplier_name"])
    return {"station_id": station_id, "organization_id": organization_id, "count": len(items), "items": items}
