from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.fuel_sale import FuelSale
from app.models.shift import Shift
from app.models.nozzle import Nozzle
from app.models.nozzle_reading import NozzleReading
from app.models.station import Station
from app.models.fuel_type import FuelType
from app.models.customer import Customer
from app.schemas.fuel_sale import FuelSaleCreate, FuelSaleResponse

router = APIRouter(prefix="/fuel-sales", tags=["Fuel Sales"])


def _ensure_sale_access(sale: FuelSale, current_user) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != sale.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this fuel sale")


@router.post("/", response_model=FuelSaleResponse)
def create_fuel_sale(
    sale_data: FuelSaleCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != sale_data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    # Find active shift if not provided
    shift_id = sale_data.shift_id
    if not shift_id:
        active_shift = db.query(Shift).filter(
            Shift.user_id == current_user.id,
            Shift.station_id == sale_data.station_id,
            Shift.status == "open",
        ).first()
        if active_shift:
            shift_id = active_shift.id
    elif shift_id:
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
        raise HTTPException(
            status_code=400,
            detail="Credit sale requires customer_id"
        )

    opening_meter = nozzle.meter_reading
    closing_meter = sale_data.closing_meter

    if closing_meter < opening_meter:
        raise HTTPException(
            status_code=400,
            detail="Closing meter cannot be less than opening meter"
        )

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
        shift_id=shift_id
    )

    db.add(sale)
    db.flush()  # to get sale.id

    # Record nozzle reading history
    nozzle_reading = NozzleReading(
        nozzle_id=sale.nozzle_id,
        reading=sale.closing_meter,
        sale_id=sale.id
    )
    db.add(nozzle_reading)

    # update nozzle meter reading
    nozzle.meter_reading = closing_meter

    # update tank volume
    if nozzle.tank:
        nozzle.tank.current_volume -= quantity

    if sale_data.sale_type == "credit" and customer is not None:
        customer.outstanding_balance += total_amount
        if customer.credit_limit > 0 and customer.outstanding_balance > customer.credit_limit:
            raise HTTPException(
                status_code=400,
                detail="Credit limit exceeded"
            )

    db.commit()
    db.refresh(sale)
    return sale


@router.get("/{sale_id}", response_model=FuelSaleResponse)
def get_fuel_sale(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    sale = db.query(FuelSale).filter(FuelSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Fuel sale not found")

    _ensure_sale_access(sale, current_user)
    return sale


@router.post("/{sale_id}/reverse", response_model=FuelSaleResponse)
def reverse_fuel_sale(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    sale = db.query(FuelSale).filter(FuelSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Fuel sale not found")

    _ensure_sale_access(sale, current_user)

    if sale.is_reversed:
        raise HTTPException(status_code=400, detail="Fuel sale is already reversed")

    nozzle = db.query(Nozzle).filter(Nozzle.id == sale.nozzle_id).first()
    if nozzle is None:
        raise HTTPException(status_code=400, detail="Cannot reverse a sale without its nozzle record")

    if nozzle.meter_reading != sale.closing_meter:
        raise HTTPException(
            status_code=400,
            detail="Fuel sale cannot be reversed after later nozzle activity"
        )

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
    sale.reversed_at = datetime.utcnow()
    sale.reversed_by = current_user.id

    db.commit()
    db.refresh(sale)
    return sale


@router.get("/", response_model=list[FuelSaleResponse])
def list_fuel_sales(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    customer_id: int | None = Query(None),
    fuel_type_id: int | None = Query(None),
    sale_type: str | None = Query(None, description="cash or credit"),
    shift_name: str | None = Query(None),
    shift_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    q = db.query(FuelSale)
    
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id
        
    if station_id:
        q = q.filter(FuelSale.station_id == station_id)
    if customer_id:
        q = q.filter(FuelSale.customer_id == customer_id)
    if fuel_type_id:
        q = q.filter(FuelSale.fuel_type_id == fuel_type_id)
    if sale_type:
        q = q.filter(FuelSale.sale_type == sale_type)
    if shift_name:
        q = q.filter(FuelSale.shift_name == shift_name)
    if shift_id:
        q = q.filter(FuelSale.shift_id == shift_id)
    if from_date:
        q = q.filter(FuelSale.created_at >= from_date)
    if to_date:
        q = q.filter(FuelSale.created_at < to_date)
    return q.order_by(FuelSale.created_at.desc()).offset(skip).limit(limit).all()
