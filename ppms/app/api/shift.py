from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.shift import Shift
from app.models.user import User
from app.schemas.shift import ShiftCreate, ShiftUpdate, ShiftResponse
from app.services.shifts import close_shift as close_shift_service
from app.services.shifts import create_shift as create_shift_service
from app.services.shifts import ensure_shift_access

router = APIRouter(prefix="/shifts", tags=["Shifts"])


@router.post("/", response_model=ShiftResponse)
def open_shift(
    data: ShiftCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return create_shift_service(db, data, current_user)


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
    return close_shift_service(db, shift, data, current_user)


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

    ensure_shift_access(shift, current_user)

    return shift
