from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.shift import Shift
from app.models.user import User
from app.schemas.shift_cash import CashSubmissionCreate, CashSubmissionResponse, ShiftCashResponse
from app.schemas.shift import ShiftCreate, ShiftUpdate, ShiftResponse
from app.services.shifts import close_shift as close_shift_service
from app.services.shifts import create_cash_submission as create_cash_submission_service
from app.services.shifts import create_shift as create_shift_service
from app.services.shifts import ensure_shift_access
from app.services.shifts import ensure_shift_cash, list_cash_submissions as list_cash_submissions_service
from app.services.shifts import sync_shift_cash

router = APIRouter(prefix="/shifts", tags=["Shifts"])


def _serialize_shift_cash(shift_cash) -> dict[str, object | None]:
    return {
        "id": shift_cash.id,
        "station_id": shift_cash.station_id,
        "shift_id": shift_cash.shift_id,
        "manager_id": shift_cash.manager_id,
        "opening_cash": shift_cash.opening_cash,
        "cash_sales": shift_cash.cash_sales,
        "expected_cash": shift_cash.expected_cash,
        "cash_submitted": shift_cash.cash_submitted,
        "closing_cash": shift_cash.closing_cash,
        "difference": shift_cash.difference,
        "cash_in_hand": round((shift_cash.expected_cash or 0.0) - (shift_cash.cash_submitted or 0.0), 2),
        "notes": shift_cash.notes,
        "created_at": shift_cash.created_at,
        "submission_count": len(shift_cash.submissions),
    }


@router.post("/", response_model=ShiftResponse)
def open_shift(
    data: ShiftCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_permission(current_user, "shifts", "open", detail="You do not have permission to open shifts")
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
    require_permission(current_user, "shifts", "close", detail="You do not have permission to close shifts")
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
    requested_station_id = station_id
    
    # Multi-tenancy check
    if current_user.role.name != "Admin" and not is_master_admin(current_user):
        if requested_station_id is not None and requested_station_id != current_user.station_id:
            raise HTTPException(status_code=403, detail="Not authorized for this station")
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


@router.get("/{shift_id}/cash", response_model=ShiftCashResponse)
def get_shift_cash(
    shift_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift = db.query(Shift).filter(Shift.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")
    require_permission(current_user, "shifts", "read", detail="You do not have permission to view shift cash")
    ensure_shift_access(shift, current_user)
    shift_cash = sync_shift_cash(db, shift)
    return _serialize_shift_cash(shift_cash)


@router.get("/{shift_id}/cash-submissions", response_model=list[CashSubmissionResponse])
def list_cash_submissions(
    shift_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift = db.query(Shift).filter(Shift.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")
    require_permission(current_user, "shifts", "read", detail="You do not have permission to view shift cash submissions")
    ensure_shift_access(shift, current_user)
    return list_cash_submissions_service(db, shift)


@router.post("/{shift_id}/cash-submissions", response_model=CashSubmissionResponse)
def create_cash_submission(
    shift_id: int,
    data: CashSubmissionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    shift = db.query(Shift).filter(Shift.id == shift_id).first()
    if not shift:
        raise HTTPException(status_code=404, detail="Shift not found")
    require_permission(current_user, "shifts", "submit_cash", detail="You do not have permission to record shift cash submissions")
    ensure_shift_access(shift, current_user)
    return create_cash_submission_service(db, shift, data, current_user)
