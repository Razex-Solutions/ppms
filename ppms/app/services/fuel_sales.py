from fastapi import HTTPException
from sqlalchemy.orm import Session

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


def ensure_sale_access(sale: FuelSale, current_user: User) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != sale.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this fuel sale")


def create_fuel_sale(db: Session, sale_data: FuelSaleCreate, current_user: User) -> FuelSale:
    if current_user.role.name != "Admin" and current_user.station_id != sale_data.station_id:
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

    db.add(NozzleReading(nozzle_id=sale.nozzle_id, reading=sale.closing_meter, sale_id=sale.id))
    nozzle.meter_reading = closing_meter
    if nozzle.tank:
        nozzle.tank.current_volume -= quantity

    if sale.sale_type == "credit" and customer is not None:
        customer.outstanding_balance += total_amount
        if customer.credit_limit > 0 and customer.outstanding_balance > customer.credit_limit:
            raise HTTPException(status_code=400, detail="Credit limit exceeded")

    db.commit()
    db.refresh(sale)
    return sale


def reverse_fuel_sale(db: Session, sale: FuelSale, current_user: User) -> FuelSale:
    ensure_sale_access(sale, current_user)
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
    db.commit()
    db.refresh(sale)
    return sale
