from fastapi import HTTPException
from sqlalchemy.orm import Session, selectinload

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.time import utc_now
from app.models.customer import Customer
from app.models.fuel_transfer import FuelTransfer
from app.models.fuel_type import FuelType
from app.models.purchase import Purchase
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.tank import Tank
from app.models.tanker import Tanker
from app.models.tanker_compartment import TankerCompartment
from app.models.tanker_delivery import TankerDelivery
from app.models.tanker_delivery_payment import TankerDeliveryPayment
from app.models.tanker_trip import TankerTrip
from app.models.tanker_trip_compartment_load import TankerTripCompartmentLoad
from app.models.tanker_trip_driver_assignment import TankerTripDriverAssignment
from app.models.tanker_trip_expense import TankerTripExpense
from app.models.user import User
from app.schemas.tanker import (
    TankerCreate,
    TankerCompartmentCreate,
    TankerCompartmentUpdate,
    TankerDeliveryCreate,
    TankerDeliveryPaymentCreate,
    TankerTripCreate,
    TankerTripExpenseCreate,
    TankerUpdate,
)
from app.services.audit import log_audit_event
from app.services.station_modules import require_station_module_enabled


MODULE_NAME = "tanker_operations"


def _load_trip(db: Session, trip_id: int) -> TankerTrip | None:
    return (
        db.query(TankerTrip)
        .options(
            selectinload(TankerTrip.deliveries).selectinload(TankerDelivery.payments),
            selectinload(TankerTrip.expenses),
            selectinload(TankerTrip.fuel_transfers),
            selectinload(TankerTrip.tanker).selectinload(Tanker.compartments),
            selectinload(TankerTrip.compartment_loads),
            selectinload(TankerTrip.driver_assignments),
            selectinload(TankerTrip.station),
            selectinload(TankerTrip.linked_tank),
            selectinload(TankerTrip.transfer_tank),
        )
        .filter(TankerTrip.id == trip_id)
        .first()
    )


def _ensure_trip_access(trip: TankerTrip, current_user: User) -> None:
    if is_master_admin(current_user):
        return
    user_org_id = get_user_organization_id(current_user)
    if is_head_office_user(current_user):
        if trip.organization_id == user_org_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this trip")
    if current_user.station_id != trip.station_id or trip.organization_id != user_org_id:
        raise HTTPException(status_code=403, detail="Not authorized for this trip")


def apply_tanker_scope(query, model, current_user: User):
    if is_master_admin(current_user):
        return query, None, None
    user_org_id = get_user_organization_id(current_user)
    if user_org_id is None:
        raise HTTPException(status_code=403, detail="User is not linked to an organization")
    if is_head_office_user(current_user):
        return query.filter(model.organization_id == user_org_id), user_org_id, None
    return query.filter(model.organization_id == user_org_id), user_org_id, current_user.station_id


def _recompute_trip_financials(trip: TankerTrip) -> None:
    trip.loaded_quantity = round(sum(item.loaded_quantity for item in trip.compartment_loads), 2)
    trip.purchase_total = round(sum(item.purchase_total for item in trip.compartment_loads), 2)
    trip.leftover_quantity = round(sum(item.remaining_quantity for item in trip.compartment_loads), 2)
    trip.total_quantity = round(sum(delivery.quantity for delivery in trip.deliveries), 2)
    trip.fuel_revenue = round(sum(delivery.fuel_amount for delivery in trip.deliveries), 2)
    trip.delivery_revenue = round(sum(delivery.delivery_charge for delivery in trip.deliveries), 2)
    trip.expense_total = round(sum(expense.amount for expense in trip.expenses), 2)

    delivered_cost = 0.0
    for delivery in trip.deliveries:
        if delivery.compartment_load is not None:
            delivered_cost += delivery.quantity * delivery.compartment_load.purchase_rate
    trip.net_profit = round((trip.fuel_revenue + trip.delivery_revenue) - delivered_cost - trip.expense_total, 2)

    total_outstanding = round(sum(delivery.outstanding_amount for delivery in trip.deliveries), 2)
    total_value = round(sum(delivery.fuel_amount + delivery.delivery_charge for delivery in trip.deliveries), 2)
    if total_outstanding <= 0:
        trip.settlement_status = "paid"
    elif total_outstanding < total_value:
        trip.settlement_status = "partial"
    else:
        trip.settlement_status = "unpaid"

    distinct_fuel_type_ids = {item.fuel_type_id for item in trip.compartment_loads}
    if len(distinct_fuel_type_ids) == 1:
        trip.fuel_type_id = next(iter(distinct_fuel_type_ids))
    elif trip.fuel_type_id is None and distinct_fuel_type_ids:
        trip.fuel_type_id = sorted(distinct_fuel_type_ids)[0]


def build_tanker_workspace_summary(
    db: Session,
    current_user: User,
    station_id: int | None = None,
) -> dict[str, object]:
    tanker_query, organization_id, scoped_station_id = apply_tanker_scope(db.query(Tanker), Tanker, current_user)
    trip_query, _, scoped_trip_station_id = apply_tanker_scope(db.query(TankerTrip), TankerTrip, current_user)
    effective_station_id = station_id or scoped_station_id or scoped_trip_station_id
    if effective_station_id is not None:
        tanker_query = tanker_query.filter(Tanker.station_id == effective_station_id)
        trip_query = trip_query.filter(TankerTrip.station_id == effective_station_id)

    tankers = tanker_query.all()
    trips = trip_query.all()
    ownership_breakdown: dict[str, int] = {}
    for tanker in tankers:
        ownership_breakdown[tanker.ownership_type or "unknown"] = ownership_breakdown.get(tanker.ownership_type or "unknown", 0) + 1

    def _sum(field: str) -> float:
        return round(sum(float(getattr(trip, field) or 0.0) for trip in trips), 2)

    return {
        "station_id": effective_station_id,
        "organization_id": organization_id,
        "tanker_count": len(tankers),
        "active_tanker_count": sum(1 for tanker in tankers if tanker.status == "active"),
        "in_progress_trip_count": sum(1 for trip in trips if trip.status in {"draft", "active", "in_transit"}),
        "completed_trip_count": sum(1 for trip in trips if trip.status in {"partially_settled", "settled"}),
        "supplier_to_station_trip_count": sum(1 for trip in trips if trip.trip_type == "supplier_to_station"),
        "supplier_to_customer_trip_count": sum(1 for trip in trips if trip.trip_type in {"supplier_to_customer", "mixed_delivery"}),
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


def _validate_compartments(compartments: list[TankerCompartmentCreate], tanker_capacity: float) -> None:
    total_capacity = 0.0
    seen_codes: set[str] = set()
    for compartment in compartments:
        if compartment.capacity <= 0:
            raise HTTPException(status_code=400, detail="Compartment capacity must be greater than 0")
        code = compartment.code.strip().upper()
        if not code:
            raise HTTPException(status_code=400, detail="Compartment code is required")
        if code in seen_codes:
            raise HTTPException(status_code=400, detail="Compartment codes must be unique per tanker")
        if compartment.position <= 0:
            raise HTTPException(status_code=400, detail="Compartment position must be greater than 0")
        seen_codes.add(code)
        total_capacity += compartment.capacity
        if total_capacity > tanker_capacity:
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
    station = db.query(Station).filter(Station.id == data.station_id).first()
    if station is None:
        raise HTTPException(status_code=404, detail="Station not found")
    user_org_id = get_user_organization_id(current_user)
    if not is_master_admin(current_user):
        if station.organization_id != user_org_id:
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        if not is_head_office_user(current_user) and current_user.station_id != data.station_id:
            raise HTTPException(status_code=403, detail="Not authorized for this station")
    require_station_module_enabled(db, data.station_id, MODULE_NAME)
    if db.query(Tanker).filter(Tanker.registration_no == data.registration_no).first():
        raise HTTPException(status_code=400, detail="Tanker registration already exists")
    if data.fuel_type_id is not None and db.query(FuelType).filter(FuelType.id == data.fuel_type_id).first() is None:
        raise HTTPException(status_code=404, detail="Fuel type not found")

    tanker = Tanker(
        registration_no=data.registration_no,
        name=data.name,
        capacity=data.capacity,
        ownership_type=data.ownership_type,
        owner_name=data.owner_name,
        status=data.status,
        organization_id=station.organization_id,
        station_id=data.station_id,
        fuel_type_id=data.fuel_type_id,
    )
    db.add(tanker)
    db.flush()
    _create_compartments(db, tanker, data.compartments)
    db.commit()
    db.refresh(tanker)
    return tanker


def update_tanker(tanker: Tanker, data: TankerUpdate, db: Session) -> Tanker:
    updated_capacity = data.capacity if data.capacity is not None else tanker.capacity
    active_compartment_capacity = sum(item.capacity for item in tanker.compartments if item.is_active)
    if updated_capacity < active_compartment_capacity:
        raise HTTPException(status_code=400, detail="Tanker capacity cannot be less than active compartment capacity")
    if data.fuel_type_id is not None and db.query(FuelType).filter(FuelType.id == data.fuel_type_id).first() is None:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(tanker, field, value)
    db.commit()
    db.refresh(tanker)
    return tanker


def create_compartment(db: Session, tanker: Tanker, data: TankerCompartmentCreate):
    _validate_compartments([data], tanker.capacity)
    duplicate = next((item for item in tanker.compartments if item.code.upper() == data.code.strip().upper()), None)
    if duplicate:
        raise HTTPException(status_code=400, detail="Compartment codes must be unique per tanker")
    active_capacity = sum(item.capacity for item in tanker.compartments if item.is_active)
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


def update_compartment(db: Session, tanker: Tanker, compartment: TankerCompartment, data: TankerCompartmentUpdate):
    updates = data.model_dump(exclude_unset=True)
    new_capacity = updates.get("capacity", compartment.capacity)
    new_is_active = updates.get("is_active", compartment.is_active)
    if new_capacity <= 0:
        raise HTTPException(status_code=400, detail="Compartment capacity must be greater than 0")
    projected_capacity = sum(item.capacity for item in tanker.compartments if item.id != compartment.id and item.is_active)
    if new_is_active and projected_capacity + new_capacity > tanker.capacity:
        raise HTTPException(status_code=400, detail="Compartment capacity cannot exceed tanker capacity")
    if "code" in updates:
        updates["code"] = updates["code"].strip().upper()
        duplicate = next((item for item in tanker.compartments if item.id != compartment.id and item.code.upper() == updates["code"]), None)
        if duplicate:
            raise HTTPException(status_code=400, detail="Compartment codes must be unique per tanker")
    if "name" in updates:
        updates["name"] = updates["name"].strip()
    for field, value in updates.items():
        setattr(compartment, field, value)
    db.commit()
    db.refresh(compartment)
    return compartment


def _validate_trip_driver_assignments(db: Session, *, trip: TankerTrip, assignments) -> None:
    seen_user_ids: set[int] = set()
    for assignment in assignments:
        if assignment.user_id in seen_user_ids:
            raise HTTPException(status_code=400, detail="Driver assignments must be unique per trip")
        seen_user_ids.add(assignment.user_id)
        user = db.query(User).filter(User.id == assignment.user_id).first()
        if user is None:
            raise HTTPException(status_code=404, detail="Assigned driver user not found")
        if get_user_organization_id(user) != trip.organization_id:
            raise HTTPException(status_code=400, detail="Assigned driver must belong to the same organization")


def _create_trip_driver_assignments(db: Session, *, trip: TankerTrip, assignments) -> None:
    for assignment in assignments:
        db.add(
            TankerTripDriverAssignment(
                trip_id=trip.id,
                user_id=assignment.user_id,
                assignment_role=assignment.assignment_role,
            )
        )


def _resolve_compartment(tanker: Tanker, compartment_id: int) -> TankerCompartment:
    compartment = next((item for item in tanker.compartments if item.id == compartment_id), None)
    if compartment is None or not compartment.is_active:
        raise HTTPException(status_code=400, detail="Trip load references an invalid or inactive compartment")
    return compartment


def _create_trip_compartment_loads(db: Session, *, trip: TankerTrip, tanker: Tanker, loads) -> None:
    seen_compartments: set[int] = set()
    for load in loads:
        if load.loaded_quantity <= 0:
            raise HTTPException(status_code=400, detail="Compartment load quantity must be greater than 0")
        if load.purchase_rate <= 0:
            raise HTTPException(status_code=400, detail="Compartment purchase rate must be greater than 0")
        if load.compartment_id in seen_compartments:
            raise HTTPException(status_code=400, detail="Each compartment may only appear once per trip")
        seen_compartments.add(load.compartment_id)
        compartment = _resolve_compartment(tanker, load.compartment_id)
        if load.loaded_quantity > compartment.capacity:
            raise HTTPException(status_code=400, detail="Compartment load cannot exceed compartment capacity")
        fuel_type = db.query(FuelType).filter(FuelType.id == load.fuel_type_id).first()
        if fuel_type is None:
            raise HTTPException(status_code=404, detail="Compartment load fuel type not found")
        db.add(
            TankerTripCompartmentLoad(
                trip_id=trip.id,
                compartment_id=compartment.id,
                fuel_type_id=load.fuel_type_id,
                loaded_quantity=round(load.loaded_quantity, 2),
                remaining_quantity=round(load.loaded_quantity, 2),
                purchase_rate=round(load.purchase_rate, 4),
                purchase_total=round(load.loaded_quantity * load.purchase_rate, 2),
            )
        )


def create_trip(db: Session, data: TankerTripCreate, current_user: User) -> TankerTrip:
    tanker = db.query(Tanker).options(selectinload(Tanker.compartments)).filter(Tanker.id == data.tanker_id).first()
    if tanker is None:
        raise HTTPException(status_code=404, detail="Tanker not found")
    user_org_id = get_user_organization_id(current_user)
    if not is_master_admin(current_user):
        if tanker.organization_id != user_org_id:
            raise HTTPException(status_code=403, detail="Not authorized for this tanker")
        if not is_head_office_user(current_user) and current_user.station_id != tanker.station_id:
            raise HTTPException(status_code=403, detail="Not authorized for this tanker")

    station_id = data.station_id or tanker.station_id
    station = db.query(Station).filter(Station.id == station_id).first()
    if station is None:
        raise HTTPException(status_code=404, detail="Station not found")
    if station.organization_id != tanker.organization_id:
        raise HTTPException(status_code=400, detail="Trip station must belong to the same organization as the tanker")
    require_station_module_enabled(db, station_id, MODULE_NAME)
    if data.trip_type not in {"supplier_to_station", "supplier_to_customer", "mixed_delivery"}:
        raise HTTPException(status_code=400, detail="Unsupported trip type")
    if data.supplier_id is not None and db.query(Supplier).filter(Supplier.id == data.supplier_id).first() is None:
        raise HTTPException(status_code=404, detail="Supplier not found")
    if data.linked_tank_id is not None:
        linked_tank = db.query(Tank).filter(Tank.id == data.linked_tank_id).first()
        if linked_tank is None:
            raise HTTPException(status_code=404, detail="Tank not found")
        if linked_tank.station_id != station_id:
            raise HTTPException(status_code=400, detail="Linked tank must belong to the trip station")

    primary_fuel_type_id = data.fuel_type_id
    if primary_fuel_type_id is None and data.compartment_loads:
        primary_fuel_type_id = data.compartment_loads[0].fuel_type_id

    trip = TankerTrip(
        tanker_id=tanker.id,
        organization_id=tanker.organization_id,
        station_id=station_id,
        supplier_id=data.supplier_id,
        fuel_type_id=primary_fuel_type_id,
        trip_type=data.trip_type,
        linked_tank_id=data.linked_tank_id,
        destination_name=data.destination_name,
        notes=data.notes,
        status="active",
    )
    db.add(trip)
    db.flush()

    loads = data.compartment_loads
    if not loads:
        if data.loaded_quantity is None or data.purchase_rate is None:
            raise HTTPException(status_code=400, detail="Trip must include compartment loads or legacy loaded_quantity and purchase_rate")
        if data.fuel_type_id is None:
            raise HTTPException(status_code=400, detail="Trip fuel_type_id is required for legacy single-load trips")
        active_compartment = next((item for item in sorted(tanker.compartments, key=lambda c: c.position) if item.is_active), None)
        if active_compartment is None:
            raise HTTPException(status_code=400, detail="Tanker must have at least one active compartment")
        loads = [type("LegacyLoad", (), {"compartment_id": active_compartment.id, "fuel_type_id": data.fuel_type_id, "loaded_quantity": data.loaded_quantity, "purchase_rate": data.purchase_rate})()]

    _create_trip_compartment_loads(db, trip=trip, tanker=tanker, loads=loads)
    _validate_trip_driver_assignments(db, trip=trip, assignments=data.driver_assignments)
    _create_trip_driver_assignments(db, trip=trip, assignments=data.driver_assignments)
    db.flush()
    trip = _load_trip(db, trip.id)
    _recompute_trip_financials(trip)
    log_audit_event(
        db,
        current_user=current_user,
        module="tankers",
        action="tankers.trip_create",
        entity_type="tanker_trip",
        entity_id=trip.id,
        station_id=trip.station_id,
        details={"trip_type": trip.trip_type, "organization_id": trip.organization_id, "loaded_quantity": trip.loaded_quantity},
    )
    db.commit()
    return _load_trip(db, trip.id)


def _resolve_delivery_compartment_load(trip: TankerTrip, *, compartment_load_id: int | None, fuel_type_id: int, quantity: float) -> TankerTripCompartmentLoad:
    eligible = [item for item in trip.compartment_loads if item.fuel_type_id == fuel_type_id and item.remaining_quantity >= quantity]
    if compartment_load_id is not None:
        selected = next((item for item in eligible if item.id == compartment_load_id), None)
        if selected is None:
            raise HTTPException(status_code=400, detail="Requested compartment load cannot cover this delivery")
        return selected
    selected = sorted(eligible, key=lambda item: item.id)[0] if eligible else None
    if selected is None:
        raise HTTPException(status_code=400, detail="No compartment load has enough remaining quantity for this delivery")
    return selected


def add_trip_delivery(db: Session, trip: TankerTrip, data: TankerDeliveryCreate, current_user: User) -> TankerTrip:
    trip = _load_trip(db, trip.id)
    _ensure_trip_access(trip, current_user)
    require_station_module_enabled(db, trip.station_id, MODULE_NAME)
    if trip.status not in {"active", "in_transit"}:
        raise HTTPException(status_code=400, detail="Deliveries can only be added to active tanker trips")
    if data.quantity <= 0 or data.fuel_rate <= 0:
        raise HTTPException(status_code=400, detail="Quantity and fuel rate must be greater than 0")
    if data.delivery_charge < 0:
        raise HTTPException(status_code=400, detail="Delivery charge cannot be negative")
    if data.sale_type not in {"cash", "credit"}:
        raise HTTPException(status_code=400, detail="sale_type must be cash or credit")
    customer = None
    if data.customer_id is not None:
        customer = db.query(Customer).filter(Customer.id == data.customer_id).first()
        if customer is None:
            raise HTTPException(status_code=404, detail="Customer not found")

    compartment_load = _resolve_delivery_compartment_load(trip, compartment_load_id=data.compartment_load_id, fuel_type_id=data.fuel_type_id, quantity=data.quantity)
    total_value = round((data.quantity * data.fuel_rate) + data.delivery_charge, 2)
    if data.paid_amount < 0 or data.paid_amount > total_value:
        raise HTTPException(status_code=400, detail="paid_amount is invalid")
    if data.sale_type == "credit" and customer is None:
        raise HTTPException(status_code=400, detail="Credit tanker delivery requires customer_id")

    delivery = TankerDelivery(
        trip_id=trip.id,
        customer_id=data.customer_id,
        fuel_type_id=data.fuel_type_id,
        compartment_load_id=compartment_load.id,
        destination_name=data.destination_name or trip.destination_name,
        quantity=round(data.quantity, 2),
        fuel_rate=round(data.fuel_rate, 4),
        fuel_amount=round(data.quantity * data.fuel_rate, 2),
        delivery_charge=round(data.delivery_charge, 2),
        sale_type=data.sale_type,
        paid_amount=round(data.paid_amount, 2),
        outstanding_amount=round(total_value - data.paid_amount, 2),
    )
    db.add(delivery)
    compartment_load.remaining_quantity = round(compartment_load.remaining_quantity - data.quantity, 2)
    if customer is not None and delivery.outstanding_amount > 0:
        customer.tanker_outstanding_balance = round((customer.tanker_outstanding_balance or 0.0) + delivery.outstanding_amount, 2)

    db.flush()
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
        details={"quantity": delivery.quantity, "fuel_amount": delivery.fuel_amount, "fuel_type_id": delivery.fuel_type_id},
    )
    db.commit()
    return _load_trip(db, trip.id)


def add_trip_delivery_payment(
    db: Session,
    trip: TankerTrip,
    delivery_id: int,
    data: TankerDeliveryPaymentCreate,
    current_user: User,
) -> TankerTrip:
    trip = _load_trip(db, trip.id)
    _ensure_trip_access(trip, current_user)
    delivery = next((item for item in trip.deliveries if item.id == delivery_id), None)
    if delivery is None:
        raise HTTPException(status_code=404, detail="Tanker delivery not found")
    if data.amount <= 0 or data.amount > delivery.outstanding_amount:
        raise HTTPException(status_code=400, detail="Payment amount is invalid")

    payment = TankerDeliveryPayment(
        delivery_id=delivery.id,
        amount=round(data.amount, 2),
        payment_method=data.payment_method,
        reference_no=data.reference_no,
        notes=data.notes,
        received_by_user_id=current_user.id,
    )
    db.add(payment)
    delivery.paid_amount = round(delivery.paid_amount + data.amount, 2)
    delivery.outstanding_amount = round(delivery.outstanding_amount - data.amount, 2)
    if delivery.customer_id is not None:
        customer = db.query(Customer).filter(Customer.id == delivery.customer_id).first()
        if customer is not None:
            customer.tanker_outstanding_balance = round(max((customer.tanker_outstanding_balance or 0.0) - data.amount, 0.0), 2)

    db.flush()
    trip = _load_trip(db, trip.id)
    _recompute_trip_financials(trip)
    if trip.leftover_quantity <= 0 and trip.settlement_status == "paid":
        trip.status = "settled"
        trip.completed_at = trip.completed_at or utc_now()
    elif trip.leftover_quantity <= 0:
        trip.status = "partially_settled"
    log_audit_event(
        db,
        current_user=current_user,
        module="tankers",
        action="tankers.delivery_payment_create",
        entity_type="tanker_delivery_payment",
        entity_id=payment.id,
        station_id=trip.station_id,
        details={"delivery_id": delivery.id, "amount": payment.amount},
    )
    db.commit()
    return _load_trip(db, trip.id)


def add_trip_expense(db: Session, trip: TankerTrip, data: TankerTripExpenseCreate, current_user: User) -> TankerTrip:
    trip = _load_trip(db, trip.id)
    _ensure_trip_access(trip, current_user)
    require_station_module_enabled(db, trip.station_id, MODULE_NAME)
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Expense amount must be greater than 0")
    expense = TankerTripExpense(trip_id=trip.id, expense_type=data.expense_type, amount=data.amount, notes=data.notes)
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


def complete_trip(
    db: Session,
    trip: TankerTrip,
    current_user: User,
    transfer_to_tank_id: int | None = None,
    transfer_quantity: float | None = None,
) -> TankerTrip:
    trip = _load_trip(db, trip.id)
    _ensure_trip_access(trip, current_user)
    require_station_module_enabled(db, trip.station_id, MODULE_NAME)
    if trip.status in {"partially_settled", "settled"}:
        raise HTTPException(status_code=400, detail="Trip is already operationally closed")

    _recompute_trip_financials(trip)

    if trip.trip_type == "supplier_to_station":
        tank = db.query(Tank).filter(Tank.id == trip.linked_tank_id).first() if trip.linked_tank_id else None
        supplier = db.query(Supplier).filter(Supplier.id == trip.supplier_id).first() if trip.supplier_id else None
        if tank is None or supplier is None:
            raise HTTPException(status_code=400, detail="Supplier-to-station trips require linked tank and supplier")
        if trip.loaded_quantity <= 0:
            raise HTTPException(status_code=400, detail="Supplier-to-station trip must have loaded quantity")
        if tank.current_volume + trip.loaded_quantity > tank.capacity:
            raise HTTPException(status_code=400, detail="Completing this trip would exceed storage tank capacity")
        effective_rate = round((trip.purchase_total / trip.loaded_quantity), 4) if trip.loaded_quantity else 0.0
        purchase = Purchase(
            supplier_id=supplier.id,
            tank_id=tank.id,
            fuel_type_id=trip.fuel_type_id or tank.fuel_type_id,
            tanker_id=trip.tanker_id,
            quantity=trip.loaded_quantity,
            rate_per_liter=effective_rate,
            total_amount=trip.purchase_total,
            reference_no=f"TANKER-TRIP-{trip.id}",
            notes=f"Generated from tanker trip {trip.id}",
            status="approved",
            submitted_by_user_id=current_user.id,
            approved_by_user_id=current_user.id,
            approved_at=utc_now(),
        )
        db.add(purchase)
        tank.current_volume += trip.loaded_quantity
        supplier.payable_balance += purchase.total_amount
        trip.linked_purchase_id = purchase.id
        for load in trip.compartment_loads:
            load.remaining_quantity = 0.0
        trip.leftover_quantity = 0.0
        trip.status = "settled"
        trip.settlement_status = "unpaid"
        trip.completed_at = utc_now()
    else:
        if trip.leftover_quantity > 0:
            if transfer_to_tank_id is None:
                raise HTTPException(status_code=400, detail="Trip still has remaining fuel and must be dumped to a tank or kept open")
            transfer_tank = db.query(Tank).filter(Tank.id == transfer_to_tank_id).first()
            if transfer_tank is None:
                raise HTTPException(status_code=404, detail="Transfer tank not found")
            remaining_loads = [item for item in trip.compartment_loads if item.remaining_quantity > 0]
            if len({item.fuel_type_id for item in remaining_loads}) != 1:
                raise HTTPException(status_code=400, detail="Mixed remaining fuel requires per-fuel settlement support before closure")
            remaining_load = remaining_loads[0]
            if transfer_tank.fuel_type_id != remaining_load.fuel_type_id:
                raise HTTPException(status_code=400, detail="Transfer tank fuel type must match remaining tanker fuel")
            transfer_amount = trip.leftover_quantity if transfer_quantity is None else transfer_quantity
            if transfer_amount <= 0 or transfer_amount > trip.leftover_quantity:
                raise HTTPException(status_code=400, detail="Transfer quantity is invalid")
            if transfer_tank.current_volume + transfer_amount > transfer_tank.capacity:
                raise HTTPException(status_code=400, detail="Completing this trip would exceed transfer tank capacity")
            transfer_tank.current_volume += transfer_amount
            remaining_load.remaining_quantity = round(remaining_load.remaining_quantity - transfer_amount, 2)
            trip.transfer_tank_id = transfer_tank.id
            trip.transferred_quantity = round((trip.transferred_quantity or 0.0) + transfer_amount, 2)
            db.add(
                FuelTransfer(
                    station_id=trip.station_id,
                    tank_id=transfer_tank.id,
                    tanker_trip_id=trip.id,
                    fuel_type_id=remaining_load.fuel_type_id,
                    quantity=transfer_amount,
                    transfer_type="tanker_leftover_to_tank",
                    notes=f"Generated from tanker trip {trip.id}",
                )
            )
            trip = _load_trip(db, trip.id)
            _recompute_trip_financials(trip)
            if trip.leftover_quantity > 0:
                raise HTTPException(status_code=400, detail="Trip still has remaining fuel after transfer")

        trip.status = "settled" if trip.settlement_status == "paid" else "partially_settled"
        trip.completed_at = utc_now()

    log_audit_event(
        db,
        current_user=current_user,
        module="tankers",
        action="tankers.trip_complete",
        entity_type="tanker_trip",
        entity_id=trip.id,
        station_id=trip.station_id,
        details={"trip_type": trip.trip_type, "status": trip.status, "settlement_status": trip.settlement_status, "leftover_quantity": trip.leftover_quantity},
    )
    db.commit()
    return _load_trip(db, trip.id)
