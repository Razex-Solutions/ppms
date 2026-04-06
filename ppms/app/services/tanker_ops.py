from fastapi import HTTPException
from sqlalchemy.orm import Session, selectinload

from app.core.access import is_master_admin
from app.core.time import utc_now
from app.models.customer import Customer
from app.models.fuel_type import FuelType
from app.models.fuel_transfer import FuelTransfer
from app.models.purchase import Purchase
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.tank import Tank
from app.models.tanker import Tanker
from app.models.tanker_compartment import TankerCompartment
from app.models.tanker_delivery import TankerDelivery
from app.models.tanker_trip import TankerTrip
from app.models.tanker_trip_expense import TankerTripExpense
from app.models.user import User
from app.schemas.tanker import (
    TankerCreate,
    TankerCompartmentCreate,
    TankerCompartmentUpdate,
    TankerDeliveryCreate,
    TankerTripCreate,
    TankerTripExpenseCreate,
    TankerUpdate,
)
from app.services.audit import log_audit_event
from app.services.station_modules import require_station_module_enabled


MODULE_NAME = "tanker_operations"


def _load_trip(db: Session, trip_id: int) -> TankerTrip | None:
    trip = db.query(TankerTrip).options(
        selectinload(TankerTrip.deliveries),
        selectinload(TankerTrip.expenses),
        selectinload(TankerTrip.fuel_transfers),
        selectinload(TankerTrip.tanker),
        selectinload(TankerTrip.tanker).selectinload(Tanker.compartments),
        selectinload(TankerTrip.station),
        selectinload(TankerTrip.linked_tank),
        selectinload(TankerTrip.transfer_tank),
    ).filter(TankerTrip.id == trip_id).first()
    if trip:
        trip.compartment_plan = _build_compartment_plan(trip)
    return trip


def _ensure_trip_access(trip: TankerTrip, current_user: User) -> None:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return
    if current_user.role.name == "HeadOffice":
        user_organization_id = current_user.station.organization_id if current_user.station else None
        if trip.station.organization_id == user_organization_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this trip")
    if current_user.station_id != trip.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this trip")


def apply_tanker_scope(query, model, current_user: User):
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return query, None
    if current_user.role.name == "HeadOffice":
        user_organization_id = current_user.station.organization_id if current_user.station else None
        if model is Tanker:
            return query.join(Tanker.station).filter(Tanker.station.has(organization_id=user_organization_id)), None
        return query.join(TankerTrip.station).filter(TankerTrip.station.has(organization_id=user_organization_id)), None
    return query, current_user.station_id


def _recompute_trip_financials(trip: TankerTrip) -> None:
    trip.total_quantity = round(sum(delivery.quantity for delivery in trip.deliveries), 2)
    effective_loaded_quantity = trip.loaded_quantity or trip.total_quantity
    if trip.loaded_quantity is not None:
        trip.leftover_quantity = round(max(trip.loaded_quantity - trip.total_quantity, 0), 2)
    else:
        trip.leftover_quantity = 0
    trip.fuel_revenue = round(sum(delivery.fuel_amount for delivery in trip.deliveries), 2)
    trip.delivery_revenue = round(sum(delivery.delivery_charge for delivery in trip.deliveries), 2)
    trip.expense_total = round(sum(expense.amount for expense in trip.expenses), 2)
    trip.purchase_total = round((effective_loaded_quantity * trip.purchase_rate), 2) if trip.purchase_rate is not None else round(trip.purchase_total or 0, 2)
    fuel_cost_of_sales = round((trip.total_quantity * trip.purchase_rate), 2) if trip.purchase_rate is not None else 0
    if trip.trip_type == "supplier_to_station":
        trip.net_profit = round(0 - trip.expense_total, 2)
    else:
        trip.net_profit = round((trip.fuel_revenue + trip.delivery_revenue) - fuel_cost_of_sales - trip.expense_total, 2)
    total_outstanding = round(sum(delivery.outstanding_amount for delivery in trip.deliveries), 2)
    total_value = round(sum(delivery.fuel_amount + delivery.delivery_charge for delivery in trip.deliveries), 2)
    if total_outstanding <= 0:
        trip.settlement_status = "paid"
    elif total_outstanding < total_value:
        trip.settlement_status = "partial"
    else:
        trip.settlement_status = "unpaid"


def build_tanker_workspace_summary(
    db: Session,
    current_user: User,
    station_id: int | None = None,
) -> dict[str, object]:
    tanker_query = db.query(Tanker)
    tanker_query, scoped_station_id = apply_tanker_scope(tanker_query, Tanker, current_user)
    trip_query = db.query(TankerTrip)
    trip_query, scoped_trip_station_id = apply_tanker_scope(trip_query, TankerTrip, current_user)
    station_id = station_id or scoped_station_id or scoped_trip_station_id
    if station_id is not None:
        tanker_query = tanker_query.filter(Tanker.station_id == station_id)
        trip_query = trip_query.filter(TankerTrip.station_id == station_id)

    tankers = tanker_query.all()
    trips = trip_query.all()
    ownership_breakdown: dict[str, int] = {}
    for tanker in tankers:
        ownership_key = tanker.ownership_type or "unknown"
        ownership_breakdown[ownership_key] = ownership_breakdown.get(ownership_key, 0) + 1

    def _sum(field: str) -> float:
        total = 0.0
        for trip in trips:
            total += float(getattr(trip, field) or 0)
        return round(total, 2)

    return {
        "station_id": station_id,
        "tanker_count": len(tankers),
        "active_tanker_count": sum(1 for tanker in tankers if tanker.status == "active"),
        "in_progress_trip_count": sum(1 for trip in trips if trip.status != "completed"),
        "completed_trip_count": sum(1 for trip in trips if trip.status == "completed"),
        "supplier_to_station_trip_count": sum(1 for trip in trips if trip.trip_type == "supplier_to_station"),
        "supplier_to_customer_trip_count": sum(1 for trip in trips if trip.trip_type == "supplier_to_customer"),
        "total_loaded_quantity": _sum("loaded_quantity"),
        "total_delivered_quantity": _sum("total_quantity"),
        "total_leftover_quantity": _sum("leftover_quantity"),
        "total_transferred_quantity": _sum("transferred_quantity"),
        "total_purchase_value": _sum("purchase_total"),
        "total_fuel_revenue": _sum("fuel_revenue"),
        "total_delivery_revenue": _sum("delivery_revenue"),
        "total_expense_value": _sum("expense_total"),
        "total_net_profit": _sum("net_profit"),
        "ownership_breakdown": ownership_breakdown,
    }


def _build_compartment_plan(trip: TankerTrip) -> list[dict[str, object]]:
    compartments = sorted(
        [compartment for compartment in trip.tanker.compartments if compartment.is_active],
        key=lambda item: item.position,
    ) if trip.tanker else []
    if not compartments or trip.loaded_quantity is None or trip.loaded_quantity <= 0:
        return []
    remaining = trip.loaded_quantity
    plan: list[dict[str, object]] = []
    for compartment in compartments:
        if remaining <= 0:
            break
        quantity = round(min(compartment.capacity, remaining), 2)
        if quantity <= 0:
            continue
        plan.append(
            {
                "compartment_id": compartment.id,
                "code": compartment.code,
                "name": compartment.name,
                "quantity": quantity,
            }
        )
        remaining = round(remaining - quantity, 2)
    return plan


def _validate_compartments(compartments: list[TankerCompartmentCreate], tanker_capacity: float) -> None:
    total_capacity = 0.0
    seen_codes: set[str] = set()
    for index, compartment in enumerate(compartments, start=1):
        if compartment.capacity <= 0:
            raise HTTPException(status_code=400, detail="Compartment capacity must be greater than 0")
        code = compartment.code.strip().upper()
        if not code:
            raise HTTPException(status_code=400, detail="Compartment code is required")
        if code in seen_codes:
            raise HTTPException(status_code=400, detail="Compartment codes must be unique per tanker")
        seen_codes.add(code)
        if compartment.position <= 0:
            raise HTTPException(status_code=400, detail="Compartment position must be greater than 0")
        total_capacity += compartment.capacity
        if total_capacity - tanker_capacity > 0.0001:
            raise HTTPException(status_code=400, detail="Compartment capacity cannot exceed tanker capacity")


def _create_compartments(db: Session, tanker: Tanker, compartments: list[TankerCompartmentCreate]) -> None:
    _validate_compartments(compartments, tanker.capacity)
    for compartment in compartments:
        db.add(
            TankerCompartment(
                tanker_id=tanker.id,
                code=compartment.code.strip().upper(),
                name=compartment.name.strip(),
                capacity=compartment.capacity,
                position=compartment.position,
                is_active=compartment.is_active,
            )
        )


def create_tanker(db: Session, data: TankerCreate, current_user: User) -> Tanker:
    if current_user.role.name != "Admin" and not is_master_admin(current_user) and current_user.station_id != data.station_id:
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
    tanker_payload = data.model_dump(exclude={"compartments"})
    tanker = Tanker(**tanker_payload)
    db.add(tanker)
    db.flush()
    _create_compartments(db, tanker, data.compartments)
    db.commit()
    db.refresh(tanker)
    return tanker


def update_tanker(tanker: Tanker, data: TankerUpdate, db: Session) -> Tanker:
    updated_capacity = data.capacity if data.capacity is not None else tanker.capacity
    active_compartment_capacity = sum(compartment.capacity for compartment in tanker.compartments if compartment.is_active)
    if updated_capacity < active_compartment_capacity:
        raise HTTPException(status_code=400, detail="Tanker capacity cannot be less than active compartment capacity")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(tanker, field, value)
    db.commit()
    db.refresh(tanker)
    return tanker


def create_compartment(
    db: Session,
    tanker: Tanker,
    data: TankerCompartmentCreate,
) -> TankerCompartment:
    _validate_compartments([data], tanker.capacity)
    duplicate = next((item for item in tanker.compartments if item.code.upper() == data.code.strip().upper()), None)
    if duplicate:
        raise HTTPException(status_code=400, detail="Compartment codes must be unique per tanker")
    active_capacity = sum(compartment.capacity for compartment in tanker.compartments if compartment.is_active)
    if active_capacity + data.capacity > tanker.capacity:
        raise HTTPException(status_code=400, detail="Compartment capacity cannot exceed tanker capacity")
    compartment = TankerCompartment(
        tanker_id=tanker.id,
        code=data.code.strip().upper(),
        name=data.name.strip(),
        capacity=data.capacity,
        position=data.position,
        is_active=data.is_active,
    )
    db.add(compartment)
    db.commit()
    db.refresh(compartment)
    return compartment


def update_compartment(
    db: Session,
    tanker: Tanker,
    compartment: TankerCompartment,
    data: TankerCompartmentUpdate,
) -> TankerCompartment:
    updates = data.model_dump(exclude_unset=True)
    new_capacity = updates.get("capacity", compartment.capacity)
    if new_capacity <= 0:
        raise HTTPException(status_code=400, detail="Compartment capacity must be greater than 0")
    new_is_active = updates.get("is_active", compartment.is_active)
    projected_capacity = sum(
        other.capacity
        for other in tanker.compartments
        if other.id != compartment.id and other.is_active
    )
    if new_is_active and projected_capacity + new_capacity > tanker.capacity:
        raise HTTPException(status_code=400, detail="Compartment capacity cannot exceed tanker capacity")
    if "code" in updates:
        normalized_code = updates["code"].strip().upper()
        if not normalized_code:
            raise HTTPException(status_code=400, detail="Compartment code is required")
        duplicate = next(
            (other for other in tanker.compartments if other.id != compartment.id and other.code.upper() == normalized_code),
            None,
        )
        if duplicate:
            raise HTTPException(status_code=400, detail="Compartment codes must be unique per tanker")
        updates["code"] = normalized_code
    if "name" in updates:
        updates["name"] = updates["name"].strip()
    for field, value in updates.items():
        setattr(compartment, field, value)
    db.commit()
    db.refresh(compartment)
    return compartment


def create_trip(db: Session, data: TankerTripCreate, current_user: User) -> TankerTrip:
    tanker = db.query(Tanker).filter(Tanker.id == data.tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    if current_user.role.name != "Admin" and not is_master_admin(current_user) and current_user.station_id != tanker.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    if data.trip_type not in {"supplier_to_station", "supplier_to_customer"}:
        raise HTTPException(status_code=400, detail="Unsupported trip type")
    if data.fuel_type_id != tanker.fuel_type_id:
        raise HTTPException(status_code=400, detail="Trip fuel type must match tanker fuel type")
    if data.trip_type == "supplier_to_station" and data.linked_tank_id is None:
        raise HTTPException(status_code=400, detail="supplier_to_station trips require linked_tank_id")
    if data.trip_type == "supplier_to_customer" and not data.destination_name:
        raise HTTPException(status_code=400, detail="supplier_to_customer trips require destination_name")
    if data.loaded_quantity is not None:
        if data.loaded_quantity <= 0:
            raise HTTPException(status_code=400, detail="loaded_quantity must be greater than 0")
        if data.loaded_quantity > tanker.capacity:
            raise HTTPException(status_code=400, detail="loaded_quantity cannot exceed tanker capacity")
    if data.purchase_rate is not None and data.purchase_rate <= 0:
        raise HTTPException(status_code=400, detail="purchase_rate must be greater than 0")
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
        loaded_quantity=data.loaded_quantity,
        purchase_rate=data.purchase_rate,
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
    existing_quantity = round(sum(existing.quantity for existing in trip.deliveries), 2)
    if trip.loaded_quantity is not None and existing_quantity + data.quantity > trip.loaded_quantity:
        raise HTTPException(status_code=400, detail="Trip deliveries cannot exceed the loaded quantity")
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


def complete_trip(db: Session, trip: TankerTrip, current_user: User, transfer_to_tank_id: int | None = None) -> TankerTrip:
    _ensure_trip_access(trip, current_user)
    require_station_module_enabled(db, trip.station_id, MODULE_NAME)
    if trip.status == "completed":
        raise HTTPException(status_code=400, detail="Trip is already completed")
    if not trip.deliveries:
        raise HTTPException(status_code=400, detail="Trip must have at least one delivery before completion")
    trip = _load_trip(db, trip.id)
    _recompute_trip_financials(trip)

    transfer = None
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
            rate_per_liter=trip.purchase_rate if trip.purchase_rate is not None else ((trip.fuel_revenue / trip.total_quantity) if trip.total_quantity else 0),
            total_amount=round(
                trip.total_quantity * trip.purchase_rate,
                2,
            ) if trip.purchase_rate is not None else trip.fuel_revenue,
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
        if trip.leftover_quantity > 0 and transfer_to_tank_id is not None:
            transfer_tank = db.query(Tank).filter(Tank.id == transfer_to_tank_id).first()
            if transfer_tank is None:
                raise HTTPException(status_code=404, detail="Transfer tank not found")
            if transfer_tank.station_id != trip.station_id:
                raise HTTPException(status_code=400, detail="Transfer tank must belong to the same station")
            if transfer_tank.fuel_type_id != trip.fuel_type_id:
                raise HTTPException(status_code=400, detail="Transfer tank fuel type must match trip fuel type")
            if transfer_tank.current_volume + trip.leftover_quantity > transfer_tank.capacity:
                raise HTTPException(status_code=400, detail="Completing this trip would exceed transfer tank capacity")
            transfer_tank.current_volume += trip.leftover_quantity
            trip.transfer_tank_id = transfer_tank.id
            trip.transferred_quantity = trip.leftover_quantity
            transfer = FuelTransfer(
                station_id=trip.station_id,
                tank_id=transfer_tank.id,
                tanker_trip_id=trip.id,
                fuel_type_id=trip.fuel_type_id,
                quantity=trip.leftover_quantity,
                transfer_type="tanker_leftover_to_tank",
                notes=f"Generated from tanker trip {trip.id}",
            )
            db.add(transfer)
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
        details={
            "trip_type": trip.trip_type,
            "net_profit": trip.net_profit,
            "linked_purchase_id": trip.linked_purchase_id,
            "leftover_quantity": trip.leftover_quantity,
            "transferred_quantity": trip.transferred_quantity,
            "transfer_tank_id": trip.transfer_tank_id,
            "fuel_transfer_id": transfer.id if transfer else None,
        },
    )
    db.commit()
    return _load_trip(db, trip.id)
