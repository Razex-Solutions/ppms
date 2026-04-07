from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.time import utc_now
from app.models.customer import Customer
from app.models.fuel_sale import FuelSale
from app.models.fuel_type import FuelType
from app.models.nozzle import Nozzle
from app.models.nozzle_reading import NozzleReading
from app.models.shift import Shift
from app.models.station import Station
from app.models.user import User
from app.schemas.fuel_sale import FuelSaleCreate
from app.services.audit import log_audit_event
from app.services.notifications import notify_approval_requested, notify_decision


def ensure_sale_access(sale: FuelSale, current_user: User) -> None:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return
    if is_head_office_user(current_user):
        if sale.station and sale.station.organization_id == get_user_organization_id(current_user):
            return
        raise HTTPException(status_code=403, detail="Not authorized for this fuel sale")
    if current_user.station_id != sale.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this fuel sale")


def create_fuel_sale(db: Session, sale_data: FuelSaleCreate, current_user: User) -> FuelSale:
    if current_user.role.name != "Admin" and not is_master_admin(current_user) and current_user.station_id != sale_data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    shift_id = sale_data.shift_id
    if not shift_id:
        active_shift = db.query(Shift).filter(
            Shift.user_id == current_user.id,
            Shift.station_id == sale_data.station_id,
            Shift.status == "open",
        ).first()
        if active_shift:
            shift_id = active_shift.id
    else:
        shift = db.query(Shift).filter(Shift.id == shift_id).first()
        if not shift:
            raise HTTPException(status_code=404, detail="Shift not found")
        if shift.station_id != sale_data.station_id:
            raise HTTPException(status_code=400, detail="Shift does not belong to the selected station")
        if shift.status != "open":
            raise HTTPException(status_code=400, detail="Fuel sales can only be recorded on an open shift")

    nozzle = db.query(Nozzle).filter(Nozzle.id == sale_data.nozzle_id).first()
    if not nozzle:
        raise HTTPException(status_code=404, detail="Nozzle not found")

    station = db.query(Station).filter(Station.id == sale_data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    fuel_type = db.query(FuelType).filter(FuelType.id == sale_data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")

    if nozzle.dispenser.station_id != sale_data.station_id:
        raise HTTPException(status_code=400, detail="Nozzle does not belong to the selected station")

    if nozzle.fuel_type_id != sale_data.fuel_type_id:
        raise HTTPException(status_code=400, detail="Nozzle fuel type does not match sale fuel type")

    if nozzle.tank and nozzle.tank.fuel_type_id != sale_data.fuel_type_id:
        raise HTTPException(status_code=400, detail="Tank fuel type does not match sale fuel type")

    customer = None
    if sale_data.customer_id is not None:
        customer = db.query(Customer).filter(Customer.id == sale_data.customer_id).first()
        if not customer:
            raise HTTPException(status_code=404, detail="Customer not found")
        if customer.station_id != sale_data.station_id:
            raise HTTPException(status_code=400, detail="Customer does not belong to the selected station")

    if sale_data.sale_type == "credit" and sale_data.customer_id is None:
        raise HTTPException(status_code=400, detail="Credit sale requires customer_id")

    opening_meter = nozzle.meter_reading
    closing_meter = sale_data.closing_meter
    if closing_meter < opening_meter:
        raise HTTPException(status_code=400, detail="Closing meter cannot be less than opening meter")
    if sale_data.rate_per_liter <= 0:
        raise HTTPException(status_code=400, detail="Rate per liter must be greater than 0")

    quantity = closing_meter - opening_meter
    total_amount = quantity * sale_data.rate_per_liter
    if nozzle.tank and quantity > nozzle.tank.current_volume:
        raise HTTPException(status_code=400, detail="Insufficient tank stock for this sale")

    sale = FuelSale(
        nozzle_id=sale_data.nozzle_id,
        station_id=sale_data.station_id,
        fuel_type_id=sale_data.fuel_type_id,
        customer_id=sale_data.customer_id,
        opening_meter=opening_meter,
        closing_meter=closing_meter,
        quantity=quantity,
        rate_per_liter=sale_data.rate_per_liter,
        total_amount=total_amount,
        sale_type=sale_data.sale_type,
        shift_name=sale_data.shift_name,
        shift_id=shift_id,
    )
    db.add(sale)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="fuel_sales",
        action="fuel_sales.create",
        entity_type="fuel_sale",
        entity_id=sale.id,
        station_id=sale.station_id,
        details={"sale_type": sale.sale_type, "total_amount": sale.total_amount, "quantity": sale.quantity},
    )

    db.add(NozzleReading(nozzle_id=sale.nozzle_id, reading=sale.closing_meter, sale_id=sale.id))
    nozzle.meter_reading = closing_meter
    if nozzle.tank:
        nozzle.tank.current_volume -= quantity

    if sale.sale_type == "credit" and customer is not None:
        projected_balance = customer.outstanding_balance + total_amount
        allowed_limit = customer.credit_limit + (customer.credit_override_amount or 0)
        if customer.credit_limit > 0 and projected_balance > allowed_limit:
            raise HTTPException(status_code=400, detail="Credit limit exceeded")
        customer.outstanding_balance = projected_balance
        if projected_balance > customer.credit_limit and customer.credit_override_amount > 0:
            excess_amount = projected_balance - customer.credit_limit
            customer.credit_override_amount = max(customer.credit_override_amount - excess_amount, 0)
            if customer.credit_override_amount == 0:
                customer.credit_override_status = None
            customer.credit_override_requested_amount = 0
            customer.credit_override_requested_at = None
            customer.credit_override_requested_by = None
            customer.credit_override_reason = None
            customer.credit_override_reviewed_at = None
            customer.credit_override_reviewed_by = None
            customer.credit_override_rejection_reason = None

    if shift_id:
        from app.services.shifts import sync_shift_cash

        shift = db.query(Shift).filter(Shift.id == shift_id).first()
        if shift:
            sync_shift_cash(db, shift)

    db.commit()
    db.refresh(sale)
    return sale


def reverse_fuel_sale(db: Session, sale: FuelSale, current_user: User) -> FuelSale:
    ensure_sale_access(sale, current_user)
    if sale.reversal_request_status != "approved" and current_user.role.name != "Admin" and not is_master_admin(current_user):
        raise HTTPException(status_code=400, detail="Fuel sale reversal must be approved first")
    if sale.is_reversed:
        raise HTTPException(status_code=400, detail="Fuel sale is already reversed")

    nozzle = db.query(Nozzle).filter(Nozzle.id == sale.nozzle_id).first()
    if nozzle is None:
        raise HTTPException(status_code=400, detail="Cannot reverse a sale without its nozzle record")
    if nozzle.meter_reading != sale.closing_meter:
        raise HTTPException(status_code=400, detail="Fuel sale cannot be reversed after later nozzle activity")
    if nozzle.tank and nozzle.tank.current_volume + sale.quantity > nozzle.tank.capacity:
        raise HTTPException(status_code=400, detail="Reversing this sale would exceed tank capacity")

    if sale.customer_id is not None:
        customer = db.query(Customer).filter(Customer.id == sale.customer_id).first()
        if customer is None:
            raise HTTPException(status_code=400, detail="Cannot reverse a sale without its customer record")
        customer.outstanding_balance -= sale.total_amount
        if customer.outstanding_balance < 0:
            raise HTTPException(status_code=400, detail="Cannot reverse sale because customer balance would become negative")

    nozzle.meter_reading = sale.opening_meter
    if nozzle.tank:
        nozzle.tank.current_volume += sale.quantity

    nozzle_reading = db.query(NozzleReading).filter(NozzleReading.sale_id == sale.id).first()
    if nozzle_reading:
        db.delete(nozzle_reading)

    sale.is_reversed = True
    sale.reversed_at = utc_now()
    sale.reversed_by = current_user.id
    log_audit_event(
        db,
        current_user=current_user,
        module="fuel_sales",
        action="fuel_sales.reverse",
        entity_type="fuel_sale",
        entity_id=sale.id,
        station_id=sale.station_id,
        details={"total_amount": sale.total_amount, "quantity": sale.quantity},
    )
    db.commit()
    db.refresh(sale)
    return sale


def request_fuel_sale_reversal(db: Session, sale: FuelSale, current_user: User, reason: str | None = None) -> FuelSale:
    ensure_sale_access(sale, current_user)
    if sale.is_reversed:
        raise HTTPException(status_code=400, detail="Fuel sale is already reversed")
    if sale.reversal_request_status == "pending":
        raise HTTPException(status_code=400, detail="Fuel sale reversal is already pending approval")

    sale.reversal_request_status = "pending"
    sale.reversal_requested_at = utc_now()
    sale.reversal_requested_by = current_user.id
    sale.reversal_request_reason = reason
    sale.reversal_reviewed_at = None
    sale.reversal_reviewed_by = None
    sale.reversal_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="fuel_sales",
        action="fuel_sales.request_reversal",
        entity_type="fuel_sale",
        entity_id=sale.id,
        station_id=sale.station_id,
        details={"reason": reason},
    )
    notify_approval_requested(
        db,
        actor_user=current_user,
        station_id=sale.station_id,
        organization_id=sale.station.organization_id if sale.station else None,
        entity_type="fuel_sale",
        entity_id=sale.id,
        title="Fuel sale reversal requested",
        message=f"{current_user.full_name} requested reversal for fuel sale #{sale.id}.",
        event_type="fuel_sale.reversal_requested",
    )
    db.commit()
    db.refresh(sale)
    return sale


def approve_fuel_sale_reversal(db: Session, sale: FuelSale, current_user: User, reason: str | None = None) -> FuelSale:
    ensure_sale_access(sale, current_user)
    if sale.is_reversed:
        raise HTTPException(status_code=400, detail="Fuel sale is already reversed")
    if sale.reversal_request_status not in {"pending", "approved"}:
        raise HTTPException(status_code=400, detail="Fuel sale reversal has not been requested")

    sale.reversal_request_status = "approved"
    sale.reversal_reviewed_at = utc_now()
    sale.reversal_reviewed_by = current_user.id
    sale.reversal_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="fuel_sales",
        action="fuel_sales.approve_reversal",
        entity_type="fuel_sale",
        entity_id=sale.id,
        station_id=sale.station_id,
        details={"reason": reason},
    )
    notify_decision(
        db,
        recipient_user_id=sale.reversal_requested_by,
        actor_user=current_user,
        station_id=sale.station_id,
        organization_id=sale.station.organization_id if sale.station else None,
        entity_type="fuel_sale",
        entity_id=sale.id,
        title="Fuel sale reversal approved",
        message=f"Reversal for fuel sale #{sale.id} was approved.",
        event_type="fuel_sale.reversal_approved",
    )
    db.flush()
    return reverse_fuel_sale(db, sale, current_user)


def reject_fuel_sale_reversal(db: Session, sale: FuelSale, current_user: User, reason: str | None = None) -> FuelSale:
    ensure_sale_access(sale, current_user)
    if sale.is_reversed:
        raise HTTPException(status_code=400, detail="Fuel sale is already reversed")
    if sale.reversal_request_status != "pending":
        raise HTTPException(status_code=400, detail="Fuel sale reversal is not pending approval")

    sale.reversal_request_status = "rejected"
    sale.reversal_reviewed_at = utc_now()
    sale.reversal_reviewed_by = current_user.id
    sale.reversal_rejection_reason = reason
    log_audit_event(
        db,
        current_user=current_user,
        module="fuel_sales",
        action="fuel_sales.reject_reversal",
        entity_type="fuel_sale",
        entity_id=sale.id,
        station_id=sale.station_id,
        details={"reason": reason},
    )
    notify_decision(
        db,
        recipient_user_id=sale.reversal_requested_by,
        actor_user=current_user,
        station_id=sale.station_id,
        organization_id=sale.station.organization_id if sale.station else None,
        entity_type="fuel_sale",
        entity_id=sale.id,
        title="Fuel sale reversal rejected",
        message=f"Reversal for fuel sale #{sale.id} was rejected.",
        event_type="fuel_sale.reversal_rejected",
    )
    db.commit()
    db.refresh(sale)
    return sale
