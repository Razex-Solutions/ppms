from datetime import date, datetime, time, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.customer_payment import CustomerPayment
from app.models.expense import Expense
from app.models.fuel_sale import FuelSale
from app.models.internal_fuel_usage import InternalFuelUsage
from app.models.nozzle import Nozzle
from app.models.pos_sale import POSSale
from app.models.purchase import Purchase
from app.models.payroll_line import PayrollLine
from app.models.payroll_run import PayrollRun
from app.models.shift import Shift
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.supplier_payment import SupplierPayment
from app.models.tank import Tank
from app.models.tanker_delivery import TankerDelivery
from app.models.tanker_trip import TankerTrip
from app.models.tanker_trip_expense import TankerTripExpense
from app.models.audit_log import AuditLog


STANDARD_REPORT_FILTERS = ["date_range", "station", "fuel_type", "staff_user", "status"]


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
        Expense.status == "approved",
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
    user_id: int | None = None,
    status: str | None = None,
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
    if user_id is not None:
        query = query.filter(Shift.user_id == user_id)
    if status is not None:
        query = query.filter(Shift.status == status)

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
    fuel_type_id: int | None = None,
) -> dict:
    tanks_query = db.query(Tank)
    if station_id is not None:
        tanks_query = tanks_query.filter(Tank.station_id == station_id)
    elif organization_id is not None:
        tanks_query = tanks_query.join(Station, Station.id == Tank.station_id).filter(Station.organization_id == organization_id)
    if fuel_type_id is not None:
        tanks_query = tanks_query.filter(Tank.fuel_type_id == fuel_type_id)

    items = []
    for tank in tanks_query.order_by(Tank.id.asc()).all():
        purchases_query = db.query(func.sum(Purchase.quantity)).filter(
            Purchase.tank_id == tank.id,
            Purchase.status == "approved",
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
    purchase_balances = purchase_balances.filter(Purchase.status == "approved")
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


def build_tanker_profit_report(
    db: Session,
    station_id: int | None,
    from_date: date | None,
    to_date: date | None,
    organization_id: int | None = None,
) -> dict:
    query = db.query(TankerTrip).filter(TankerTrip.status == "completed")
    if station_id is not None:
        query = query.filter(TankerTrip.station_id == station_id)
    elif organization_id is not None:
        query = query.join(Station, Station.id == TankerTrip.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        query = query.filter(TankerTrip.completed_at >= from_date)
    if to_date:
        query = query.filter(TankerTrip.completed_at < to_date)

    trips = query.order_by(TankerTrip.completed_at.desc(), TankerTrip.id.desc()).all()
    items = [
        {
            "trip_id": trip.id,
            "station_id": trip.station_id,
            "tanker_id": trip.tanker_id,
            "trip_type": trip.trip_type,
            "status": trip.status,
            "destination_name": trip.destination_name,
            "completed_at": trip.completed_at,
            "total_quantity": round(trip.total_quantity or 0.0, 2),
            "fuel_revenue": round(trip.fuel_revenue or 0.0, 2),
            "delivery_revenue": round(trip.delivery_revenue or 0.0, 2),
            "expense_total": round(trip.expense_total or 0.0, 2),
            "net_profit": round(trip.net_profit or 0.0, 2),
        }
        for trip in trips
    ]
    return {
        "station_id": station_id,
        "organization_id": organization_id,
        "count": len(items),
        "total_fuel_revenue": round(sum(item["fuel_revenue"] for item in items), 2),
        "total_delivery_revenue": round(sum(item["delivery_revenue"] for item in items), 2),
        "total_expenses": round(sum(item["expense_total"] for item in items), 2),
        "total_net_profit": round(sum(item["net_profit"] for item in items), 2),
        "items": items,
    }


def build_tanker_delivery_report(
    db: Session,
    station_id: int | None,
    from_date: date | None,
    to_date: date | None,
    organization_id: int | None = None,
    fuel_type_id: int | None = None,
    status: str | None = None,
    user_id: int | None = None,
) -> dict:
    query = db.query(TankerDelivery).join(TankerTrip, TankerTrip.id == TankerDelivery.trip_id)
    if station_id is not None:
        query = query.filter(TankerTrip.station_id == station_id)
    elif organization_id is not None:
        query = query.join(Station, Station.id == TankerTrip.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        query = query.filter(TankerDelivery.created_at >= from_date)
    if to_date:
        query = query.filter(TankerDelivery.created_at < to_date)
    if fuel_type_id is not None:
        query = query.filter(TankerDelivery.fuel_type_id == fuel_type_id)
    if status is not None:
        query = query.filter(TankerTrip.status == status)
    if user_id is not None:
        query = query.filter(TankerDelivery.customer_id == user_id)

    deliveries = query.order_by(TankerDelivery.created_at.desc(), TankerDelivery.id.desc()).all()
    items = [
        {
            "delivery_id": delivery.id,
            "trip_id": delivery.trip_id,
            "station_id": delivery.trip.station_id,
            "customer_id": delivery.customer_id,
            "destination_name": delivery.destination_name,
            "sale_type": delivery.sale_type,
            "quantity": round(delivery.quantity or 0.0, 2),
            "fuel_amount": round(delivery.fuel_amount or 0.0, 2),
            "delivery_charge": round(delivery.delivery_charge or 0.0, 2),
            "paid_amount": round(delivery.paid_amount or 0.0, 2),
            "outstanding_amount": round(delivery.outstanding_amount or 0.0, 2),
            "created_at": delivery.created_at,
        }
        for delivery in deliveries
    ]
    return {
        "station_id": station_id,
        "organization_id": organization_id,
        "count": len(items),
        "total_quantity": round(sum(item["quantity"] for item in items), 2),
        "fuel_revenue": round(sum(item["fuel_amount"] for item in items), 2),
        "delivery_revenue": round(sum(item["delivery_charge"] for item in items), 2),
        "cash_collected": round(sum(item["paid_amount"] for item in items), 2),
        "credit_outstanding": round(sum(item["outstanding_amount"] for item in items), 2),
        "items": items,
    }


def build_tanker_expense_report(
    db: Session,
    station_id: int | None,
    from_date: date | None,
    to_date: date | None,
    organization_id: int | None = None,
    status: str | None = None,
) -> dict:
    query = db.query(TankerTripExpense).join(TankerTrip, TankerTrip.id == TankerTripExpense.trip_id)
    if station_id is not None:
        query = query.filter(TankerTrip.station_id == station_id)
    elif organization_id is not None:
        query = query.join(Station, Station.id == TankerTrip.station_id).filter(Station.organization_id == organization_id)
    if from_date:
        query = query.filter(TankerTripExpense.created_at >= from_date)
    if to_date:
        query = query.filter(TankerTripExpense.created_at < to_date)
    if status is not None:
        query = query.filter(TankerTrip.status == status)

    expenses = query.order_by(TankerTripExpense.created_at.desc(), TankerTripExpense.id.desc()).all()
    items = [
        {
            "expense_id": expense.id,
            "trip_id": expense.trip_id,
            "station_id": expense.trip.station_id,
            "tanker_id": expense.trip.tanker_id,
            "expense_type": expense.expense_type,
            "amount": round(expense.amount or 0.0, 2),
            "notes": expense.notes,
            "created_at": expense.created_at,
        }
        for expense in expenses
    ]
    return {
        "station_id": station_id,
        "organization_id": organization_id,
        "count": len(items),
        "total_expenses": round(sum(item["amount"] for item in items), 2),
        "items": items,
    }


def build_profit_summary(
    db: Session,
    station_id: int | None,
    organization_id: int | None,
    from_date: date | None = None,
    to_date: date | None = None,
) -> dict:
    fuel_cash_sales_query = db.query(func.sum(FuelSale.total_amount)).filter(
        FuelSale.sale_type == "cash",
        FuelSale.is_reversed.is_(False),
    )
    fuel_credit_sales_query = db.query(func.sum(FuelSale.total_amount)).filter(
        FuelSale.sale_type == "credit",
        FuelSale.is_reversed.is_(False),
    )
    pos_sales_query = db.query(func.sum(POSSale.total_amount)).filter(
        POSSale.is_reversed.is_(False),
    )
    purchases_query = db.query(func.sum(Purchase.total_amount)).filter(
        Purchase.status == "approved",
        Purchase.is_reversed.is_(False),
    )
    expenses_query = db.query(func.sum(Expense.amount)).filter(
        Expense.status == "approved",
    )
    internal_usage_query = db.query(InternalFuelUsage).join(Tank, Tank.id == InternalFuelUsage.tank_id)

    if station_id is not None:
        fuel_cash_sales_query = fuel_cash_sales_query.filter(FuelSale.station_id == station_id)
        fuel_credit_sales_query = fuel_credit_sales_query.filter(FuelSale.station_id == station_id)
        pos_sales_query = pos_sales_query.filter(POSSale.station_id == station_id)
        purchases_query = purchases_query.join(Tank, Tank.id == Purchase.tank_id).filter(Tank.station_id == station_id)
        expenses_query = expenses_query.filter(Expense.station_id == station_id)
        internal_usage_query = internal_usage_query.filter(InternalFuelUsage.station_id == station_id)
    elif organization_id is not None:
        fuel_cash_sales_query = fuel_cash_sales_query.join(Station, Station.id == FuelSale.station_id).filter(Station.organization_id == organization_id)
        fuel_credit_sales_query = fuel_credit_sales_query.join(Station, Station.id == FuelSale.station_id).filter(Station.organization_id == organization_id)
        pos_sales_query = pos_sales_query.join(Station, Station.id == POSSale.station_id).filter(Station.organization_id == organization_id)
        purchases_query = purchases_query.join(Tank, Tank.id == Purchase.tank_id).join(Station, Station.id == Tank.station_id).filter(
            Station.organization_id == organization_id
        )
        expenses_query = expenses_query.join(Station, Station.id == Expense.station_id).filter(Station.organization_id == organization_id)
        internal_usage_query = internal_usage_query.join(Station, Station.id == InternalFuelUsage.station_id).filter(
            Station.organization_id == organization_id
        )

    if from_date:
        fuel_cash_sales_query = fuel_cash_sales_query.filter(FuelSale.created_at >= from_date)
        fuel_credit_sales_query = fuel_credit_sales_query.filter(FuelSale.created_at >= from_date)
        pos_sales_query = pos_sales_query.filter(POSSale.created_at >= from_date)
        purchases_query = purchases_query.filter(Purchase.created_at >= from_date)
        expenses_query = expenses_query.filter(Expense.created_at >= from_date)
        internal_usage_query = internal_usage_query.filter(InternalFuelUsage.created_at >= from_date)
    if to_date:
        fuel_cash_sales_query = fuel_cash_sales_query.filter(FuelSale.created_at < to_date)
        fuel_credit_sales_query = fuel_credit_sales_query.filter(FuelSale.created_at < to_date)
        pos_sales_query = pos_sales_query.filter(POSSale.created_at < to_date)
        purchases_query = purchases_query.filter(Purchase.created_at < to_date)
        expenses_query = expenses_query.filter(Expense.created_at < to_date)
        internal_usage_query = internal_usage_query.filter(InternalFuelUsage.created_at < to_date)

    total_cash_sales = fuel_cash_sales_query.scalar() or 0.0
    total_credit_sales = fuel_credit_sales_query.scalar() or 0.0
    total_pos_sales = pos_sales_query.scalar() or 0.0
    total_purchase_cost = purchases_query.scalar() or 0.0
    total_expenses = expenses_query.scalar() or 0.0

    internal_fuel_cost = 0.0
    usage_items = internal_usage_query.all()
    for usage in usage_items:
        latest_purchase = db.query(Purchase).filter(
            Purchase.tank_id == usage.tank_id,
            Purchase.status == "approved",
            Purchase.is_reversed.is_(False),
        ).order_by(Purchase.created_at.desc(), Purchase.id.desc()).first()
        rate = latest_purchase.rate_per_liter if latest_purchase else 0.0
        internal_fuel_cost += (usage.quantity or 0.0) * (rate or 0.0)

    total_sales = total_cash_sales + total_credit_sales + total_pos_sales
    gross_margin = total_sales - total_purchase_cost
    net_profit = gross_margin - total_expenses - internal_fuel_cost
    return {
        "station_id": station_id,
        "organization_id": organization_id,
        "total_cash_sales": round(total_cash_sales, 2),
        "total_credit_sales": round(total_credit_sales, 2),
        "total_pos_sales": round(total_pos_sales, 2),
        "total_sales": round(total_sales, 2),
        "total_purchase_cost": round(total_purchase_cost, 2),
        "total_expenses": round(total_expenses, 2),
        "total_internal_fuel_cost": round(internal_fuel_cost, 2),
        "gross_margin": round(gross_margin, 2),
        "net_profit": round(net_profit, 2),
    }


def build_staff_payroll_summary_report(
    db: Session,
    station_id: int | None,
    from_date: date | None,
    to_date: date | None,
    organization_id: int | None = None,
    user_id: int | None = None,
    status: str | None = None,
) -> dict:
    query = db.query(PayrollRun).join(Station, Station.id == PayrollRun.station_id)
    if station_id is not None:
        query = query.filter(PayrollRun.station_id == station_id)
    elif organization_id is not None:
        query = query.filter(Station.organization_id == organization_id)
    if from_date is not None:
        query = query.filter(PayrollRun.period_start >= from_date)
    if to_date is not None:
        query = query.filter(PayrollRun.period_end <= to_date)
    if status is not None:
        query = query.filter(PayrollRun.status == status)

    runs = query.order_by(PayrollRun.period_end.desc(), PayrollRun.id.desc()).all()
    run_ids = [run.id for run in runs]
    lines_query = db.query(PayrollLine).filter(PayrollLine.payroll_run_id.in_(run_ids)) if run_ids else db.query(PayrollLine).filter(False)
    if user_id is not None:
        lines_query = lines_query.filter(PayrollLine.user_id == user_id)
    lines = lines_query.all()
    lines_by_run: dict[int, list[PayrollLine]] = {}
    for line in lines:
        lines_by_run.setdefault(line.payroll_run_id, []).append(line)

    items = []
    for run in runs:
        run_lines = lines_by_run.get(run.id, [])
        if user_id is not None and not run_lines:
            continue
        items.append(
            {
                "payroll_run_id": run.id,
                "station_id": run.station_id,
                "status": run.status,
                "period_start": run.period_start,
                "period_end": run.period_end,
                "staff_count": len(run_lines) if user_id is not None else run.total_staff,
                "gross_amount": round(sum(line.gross_amount or 0.0 for line in run_lines), 2) if user_id is not None else round(run.total_gross_amount or 0.0, 2),
                "deductions": round(sum(line.deductions or 0.0 for line in run_lines), 2) if user_id is not None else round(run.total_deductions or 0.0, 2),
                "net_amount": round(sum(line.net_amount or 0.0 for line in run_lines), 2) if user_id is not None else round(run.total_net_amount or 0.0, 2),
            }
        )

    return {
        "station_id": station_id,
        "organization_id": organization_id,
        "count": len(items),
        "total_gross_amount": round(sum(item["gross_amount"] for item in items), 2),
        "total_deductions": round(sum(item["deductions"] for item in items), 2),
        "total_net_amount": round(sum(item["net_amount"] for item in items), 2),
        "items": items,
    }


def build_exception_variance_report(
    db: Session,
    station_id: int | None,
    from_date: date | None,
    to_date: date | None,
    organization_id: int | None = None,
    user_id: int | None = None,
    status: str | None = None,
) -> dict:
    items: list[dict] = []

    shift_query = db.query(Shift).filter(Shift.status == "closed")
    if station_id is not None:
        shift_query = shift_query.filter(Shift.station_id == station_id)
    elif organization_id is not None:
        shift_query = shift_query.join(Station, Station.id == Shift.station_id).filter(Station.organization_id == organization_id)
    if from_date is not None:
        shift_query = shift_query.filter(Shift.end_time >= from_date)
    if to_date is not None:
        shift_query = shift_query.filter(Shift.end_time < to_date)
    if user_id is not None:
        shift_query = shift_query.filter(Shift.user_id == user_id)
    for shift in shift_query.all():
        difference = round(shift.difference or 0.0, 2)
        if difference != 0:
            items.append(
                {
                    "category": "cash_variance",
                    "severity": "medium" if abs(difference) < 500 else "high",
                    "station_id": shift.station_id,
                    "entity_type": "shift",
                    "entity_id": shift.id,
                    "status": shift.status,
                    "amount": difference,
                    "created_at": shift.end_time,
                    "detail": f"Shift #{shift.id} closed with cash variance {difference}.",
                }
            )

    customer_query = db.query(Customer)
    if station_id is not None:
        customer_query = customer_query.filter(Customer.station_id == station_id)
    elif organization_id is not None:
        customer_query = customer_query.join(Station, Station.id == Customer.station_id).filter(Station.organization_id == organization_id)
    for customer in customer_query.all():
        if (customer.credit_limit or 0.0) > 0 and (customer.outstanding_balance or 0.0) > customer.credit_limit:
            items.append(
                {
                    "category": "credit_limit_breach",
                    "severity": "high",
                    "station_id": customer.station_id,
                    "entity_type": "customer",
                    "entity_id": customer.id,
                    "status": "open",
                    "amount": round(customer.outstanding_balance - customer.credit_limit, 2),
                    "created_at": None,
                    "detail": f"{customer.name} exceeded credit limit.",
                }
            )

    audit_query = db.query(AuditLog)
    if station_id is not None:
        audit_query = audit_query.filter(AuditLog.station_id == station_id)
    elif organization_id is not None:
        audit_query = audit_query.join(Station, Station.id == AuditLog.station_id).filter(Station.organization_id == organization_id)
    if from_date is not None:
        audit_query = audit_query.filter(AuditLog.created_at >= from_date)
    if to_date is not None:
        audit_query = audit_query.filter(AuditLog.created_at < to_date)
    if user_id is not None:
        audit_query = audit_query.filter(AuditLog.user_id == user_id)
    unusual_actions = {"customer_payments.delete", "supplier_payments.delete", "expenses.delete", "tankers.delivery_payment_create"}
    for log in audit_query.all():
        if log.action in unusual_actions:
            items.append(
                {
                    "category": "unusual_edit_or_removal",
                    "severity": "medium",
                    "station_id": log.station_id,
                    "entity_type": log.entity_type,
                    "entity_id": log.entity_id,
                    "status": "logged",
                    "amount": None,
                    "created_at": log.created_at,
                    "detail": f"Audit action {log.action} was recorded.",
                }
            )

    if status is not None:
        items = [item for item in items if item["status"] == status]
    items.sort(key=lambda item: (item["created_at"] is None, item["created_at"]), reverse=True)
    return {
        "station_id": station_id,
        "organization_id": organization_id,
        "count": len(items),
        "items": items,
    }
