from fastapi import HTTPException
from sqlalchemy.orm import Session, selectinload

from app.core.time import utc_now
from app.models.customer import Customer
from app.models.fuel_type import FuelType
from app.models.purchase import Purchase
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.tank import Tank
from app.models.tanker import Tanker
from app.models.tanker_delivery import TankerDelivery
from app.models.tanker_trip import TankerTrip
from app.models.tanker_trip_expense import TankerTripExpense
from app.models.user import User
from app.schemas.tanker import (
    TankerCreate,
    TankerDeliveryCreate,
    TankerTripCreate,
    TankerTripExpenseCreate,
    TankerUpdate,
)
from app.services.audit import log_audit_event
from app.services.station_modules import require_station_module_enabled


MODULE_NAME = "tanker_operations"


def _load_trip(db: Session, trip_id: int) -> TankerTrip | None:
    return db.query(TankerTrip).options(
        selectinload(TankerTrip.deliveries),
        selectinload(TankerTrip.expenses),
        selectinload(TankerTrip.tanker),
        selectinload(TankerTrip.station),
        selectinload(TankerTrip.linked_tank),
    ).filter(TankerTrip.id == trip_id).first()


def _ensure_trip_access(trip: TankerTrip, current_user: User) -> None:
    if current_user.role.name == "Admin":
        return
    if current_user.role.name == "HeadOffice":
        user_organization_id = current_user.station.organization_id if current_user.station else None
        if trip.station.organization_id == user_organization_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this trip")
    if current_user.station_id != trip.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this trip")


def _recompute_trip_financials(trip: TankerTrip) -> None:
    trip.total_quantity = round(sum(delivery.quantity for delivery in trip.deliveries), 2)
    trip.fuel_revenue = round(sum(delivery.fuel_amount for delivery in trip.deliveries), 2)
    trip.delivery_revenue = round(sum(delivery.delivery_charge for delivery in trip.deliveries), 2)
    trip.expense_total = round(sum(expense.amount for expense in trip.expenses), 2)
    if trip.trip_type == "supplier_to_station":
        trip.net_profit = round(0 - trip.expense_total, 2)
    else:
        trip.net_profit = round((trip.fuel_revenue + trip.delivery_revenue) - trip.expense_total, 2)
    total_outstanding = round(sum(delivery.outstanding_amount for delivery in trip.deliveries), 2)
    total_value = round(sum(delivery.fuel_amount + delivery.delivery_charge for delivery in trip.deliveries), 2)
    if total_outstanding <= 0:
        trip.settlement_status = "paid"
    elif total_outstanding < total_value:
        trip.settlement_status = "partial"
    else:
        trip.settlement_status = "unpaid"


def create_tanker(db: Session, data: TankerCreate, current_user: User) -> Tanker:
    if current_user.role.name != "Admin" and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    require_station_module_enabled(db, data.station_id, MODULE_NAME)
    existing = db.query(Tanker).filter(Tanker.registration_no == data.registration_no).first()
    if existing:
        raise HTTPException(status_code=400, detail="Tanker registration already exists")
    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    fuel_type = db.query(FuelType).filter(FuelType.id == data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    tanker = Tanker(**data.model_dump())
    db.add(tanker)
    db.commit()
    db.refresh(tanker)
    return tanker


def update_tanker(tanker: Tanker, data: TankerUpdate, db: Session) -> Tanker:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(tanker, field, value)
    db.commit()
    db.refresh(tanker)
    return tanker


def create_trip(db: Session, data: TankerTripCreate, current_user: User) -> TankerTrip:
    tanker = db.query(Tanker).filter(Tanker.id == data.tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    if current_user.role.name != "Admin" and current_user.station_id != tanker.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    if data.trip_type not in {"supplier_to_station", "supplier_to_customer"}:
        raise HTTPException(status_code=400, detail="Unsupported trip type")
    if data.trip_type == "supplier_to_station" and data.linked_tank_id is None:
        raise HTTPException(status_code=400, detail="supplier_to_station trips require linked_tank_id")
    if data.trip_type == "supplier_to_customer" and not data.destination_name:
        raise HTTPException(status_code=400, detail="supplier_to_customer trips require destination_name")
    if data.supplier_id is not None:
        supplier = db.query(Supplier).filter(Supplier.id == data.supplier_id).first()
        if not supplier:
            raise HTTPException(status_code=404, detail="Supplier not found")
    if data.linked_tank_id is not None:
        tank = db.query(Tank).filter(Tank.id == data.linked_tank_id).first()
        if not tank:
            raise HTTPException(status_code=404, detail="Tank not found")
        if tank.station_id != tanker.station_id:
            raise HTTPException(status_code=400, detail="Linked tank must belong to the same station as the tanker")
        if tank.fuel_type_id != data.fuel_type_id:
            raise HTTPException(status_code=400, detail="Linked tank fuel type must match trip fuel type")
    trip = TankerTrip(
        tanker_id=tanker.id,
        station_id=tanker.station_id,
        supplier_id=data.supplier_id,
        fuel_type_id=data.fuel_type_id,
        trip_type=data.trip_type,
        linked_tank_id=data.linked_tank_id,
        destination_name=data.destination_name,
        notes=data.notes,
        status="in_progress",
    )
    db.add(trip)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="tankers",
        action="tankers.trip_create",
        entity_type="tanker_trip",
        entity_id=trip.id,
        station_id=trip.station_id,
        details={"trip_type": trip.trip_type, "destination_name": trip.destination_name},
    )
    db.commit()
    return _load_trip(db, trip.id)


def add_trip_delivery(db: Session, trip: TankerTrip, data: TankerDeliveryCreate, current_user: User) -> TankerTrip:
    _ensure_trip_access(trip, current_user)
    require_station_module_enabled(db, trip.station_id, MODULE_NAME)
    if trip.status != "in_progress":
        raise HTTPException(status_code=400, detail="Deliveries can only be added to in-progress trips")
    if data.quantity <= 0 or data.fuel_rate <= 0:
        raise HTTPException(status_code=400, detail="Quantity and fuel rate must be greater than 0")
    if data.delivery_charge < 0:
        raise HTTPException(status_code=400, detail="Delivery charge cannot be negative")
    if data.sale_type not in {"cash", "credit"}:
        raise HTTPException(status_code=400, detail="sale_type must be cash or credit")
    customer = None
    if data.customer_id is not None:
        customer = db.query(Customer).filter(Customer.id == data.customer_id).first()
        if not customer:
            raise HTTPException(status_code=404, detail="Customer not found")
        if customer.station_id != trip.station_id:
            raise HTTPException(status_code=400, detail="Customer must belong to the trip station")
    total_value = round((data.quantity * data.fuel_rate) + data.delivery_charge, 2)
    if data.paid_amount < 0 or data.paid_amount > total_value:
        raise HTTPException(status_code=400, detail="paid_amount is invalid")
    if data.sale_type == "credit" and customer is None:
        raise HTTPException(status_code=400, detail="Credit tanker delivery requires customer_id")
    delivery = TankerDelivery(
        trip_id=trip.id,
        customer_id=data.customer_id,
        destination_name=data.destination_name or trip.destination_name,
        quantity=data.quantity,
        fuel_rate=data.fuel_rate,
        fuel_amount=round(data.quantity * data.fuel_rate, 2),
        delivery_charge=data.delivery_charge,
        sale_type=data.sale_type,
        paid_amount=data.paid_amount,
        outstanding_amount=round(total_value - data.paid_amount, 2),
    )
    db.add(delivery)
    db.flush()
    db.refresh(trip)
    trip = _load_trip(db, trip.id)
    _recompute_trip_financials(trip)
    log_audit_event(
        db,
        current_user=current_user,
        module="tankers",
        action="tankers.delivery_create",
        entity_type="tanker_delivery",
        entity_id=delivery.id,
        station_id=trip.station_id,
        details={"quantity": delivery.quantity, "fuel_amount": delivery.fuel_amount, "delivery_charge": delivery.delivery_charge},
    )
    db.commit()
    return _load_trip(db, trip.id)


def add_trip_expense(db: Session, trip: TankerTrip, data: TankerTripExpenseCreate, current_user: User) -> TankerTrip:
    _ensure_trip_access(trip, current_user)
    require_station_module_enabled(db, trip.station_id, MODULE_NAME)
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Expense amount must be greater than 0")
    expense = TankerTripExpense(
        trip_id=trip.id,
        expense_type=data.expense_type,
        amount=data.amount,
        notes=data.notes,
    )
    db.add(expense)
    db.flush()
    trip = _load_trip(db, trip.id)
    _recompute_trip_financials(trip)
    log_audit_event(
        db,
        current_user=current_user,
        module="tankers",
        action="tankers.expense_create",
        entity_type="tanker_trip_expense",
        entity_id=expense.id,
        station_id=trip.station_id,
        details={"expense_type": expense.expense_type, "amount": expense.amount},
    )
    db.commit()
    return _load_trip(db, trip.id)


def complete_trip(db: Session, trip: TankerTrip, current_user: User) -> TankerTrip:
    _ensure_trip_access(trip, current_user)
    require_station_module_enabled(db, trip.station_id, MODULE_NAME)
    if trip.status == "completed":
        raise HTTPException(status_code=400, detail="Trip is already completed")
    if not trip.deliveries:
        raise HTTPException(status_code=400, detail="Trip must have at least one delivery before completion")
    trip = _load_trip(db, trip.id)
    _recompute_trip_financials(trip)

    if trip.trip_type == "supplier_to_station":
        tank = db.query(Tank).filter(Tank.id == trip.linked_tank_id).first()
        supplier = db.query(Supplier).filter(Supplier.id == trip.supplier_id).first() if trip.supplier_id else None
        if tank is None or supplier is None:
            raise HTTPException(status_code=400, detail="Supplier-to-station trips require linked tank and supplier")
        if tank.current_volume + trip.total_quantity > tank.capacity:
            raise HTTPException(status_code=400, detail="Completing this trip would exceed storage tank capacity")
        purchase = Purchase(
            supplier_id=supplier.id,
            tank_id=tank.id,
            fuel_type_id=trip.fuel_type_id,
            tanker_id=trip.tanker_id,
            quantity=trip.total_quantity,
            rate_per_liter=(trip.fuel_revenue / trip.total_quantity) if trip.total_quantity else 0,
            total_amount=trip.fuel_revenue,
            reference_no=f"TANKER-TRIP-{trip.id}",
            notes=f"Generated from tanker trip {trip.id}",
            status="approved",
            submitted_by_user_id=current_user.id,
            approved_by_user_id=current_user.id,
            approved_at=utc_now(),
        )
        db.add(purchase)
        db.flush()
        tank.current_volume += trip.total_quantity
        supplier.payable_balance += purchase.total_amount
        trip.linked_purchase_id = purchase.id
    else:
        for delivery in trip.deliveries:
            if delivery.sale_type == "credit" and delivery.customer_id is not None:
                customer = db.query(Customer).filter(Customer.id == delivery.customer_id).first()
                if customer:
                    customer.outstanding_balance += delivery.outstanding_amount

    trip.status = "completed"
    trip.completed_at = utc_now()
    log_audit_event(
        db,
        current_user=current_user,
        module="tankers",
        action="tankers.trip_complete",
        entity_type="tanker_trip",
        entity_id=trip.id,
        station_id=trip.station_id,
        details={"trip_type": trip.trip_type, "net_profit": trip.net_profit, "linked_purchase_id": trip.linked_purchase_id},
    )
    db.commit()
    return _load_trip(db, trip.id)
