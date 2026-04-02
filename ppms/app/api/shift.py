from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.shift import Shift
from app.models.user import User
from app.models.station import Station
from app.models.fuel_sale import FuelSale
from app.schemas.shift import ShiftCreate, ShiftUpdate, ShiftResponse

router = APIRouter(prefix="/shifts", tags=["Shifts"])


@router.post("/", response_model=ShiftResponse)
def open_shift(
    data: ShiftCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")

    # Check if user already has an open shift at this station
    open_shift = db.query(Shift).filter(
        Shift.user_id == current_user.id,
        Shift.station_id == data.station_id,
        Shift.status == "open"
    ).first()
    
    if open_shift:
        raise HTTPException(
            status_code=400,
            detail=f"You already have an open shift (ID: {open_shift.id}) at this station"
        )

    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    shift = Shift(
        station_id=data.station_id,
        user_id=current_user.id,
        initial_cash=data.initial_cash,
        expected_cash=data.initial_cash,
        notes=data.notes,
        status="open",
        start_time=datetime.utcnow()
    )
    
    db.add(shift)
    db.commit()
    db.refresh(shift)
    return shift


@router.post("/{shift_id}/close", response_model=ShiftResponse)
def close_shift(
    shift_id: int,
    data: ShiftUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    shift = db.query(Shift).filter(Shift.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")
    
    if shift.status == "closed":
        raise HTTPException(status_code=400, detail="Shift is already closed")
    
    if shift.user_id != current_user.id:
         # Optionally allow managers to close others' shifts, but for now strict
         raise HTTPException(status_code=403, detail="You can only close your own shifts")

    # Calculate totals from sales
    sales = db.query(FuelSale).filter(
        FuelSale.shift_id == shift_id,
        FuelSale.is_reversed.is_(False)
    ).all()
    
    total_cash = sum(s.total_amount for s in sales if s.sale_type == "cash")
    total_credit = sum(s.total_amount for s in sales if s.sale_type == "credit")
    
    shift.total_sales_cash = total_cash
    shift.total_sales_credit = total_credit
    shift.expected_cash = shift.initial_cash + total_cash
    shift.actual_cash_collected = data.actual_cash_collected
    shift.difference = shift.actual_cash_collected - shift.expected_cash
    
    shift.status = "closed"
    shift.end_time = datetime.utcnow()
    shift.notes = data.notes if data.notes else shift.notes
    
    db.commit()
    db.refresh(shift)
    return shift


@router.get("/", response_model=list[ShiftResponse])
def list_shifts(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    user_id: int | None = Query(None),
    status: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    q = db.query(Shift)
    
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id
        
    if station_id:
        q = q.filter(Shift.station_id == station_id)
    if user_id:
        q = q.filter(Shift.user_id == user_id)
    if status:
        q = q.filter(Shift.status == status)
        
    return q.order_by(Shift.start_time.desc()).offset(skip).limit(limit).all()


@router.get("/{shift_id}", response_model=ShiftResponse)
def get_shift(
    shift_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    shift = db.query(Shift).filter(Shift.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")

    if current_user.role.name != "Admin" and current_user.station_id != shift.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this shift")

    return shift
