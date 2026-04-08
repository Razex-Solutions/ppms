from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.salary_adjustment import SalaryAdjustment
from app.models.employee_profile import EmployeeProfile
from app.models.station import Station
from app.models.user import User
from app.schemas.salary_adjustment import SalaryAdjustmentCreate, SalaryAdjustmentResponse


router = APIRouter(prefix="/salary-adjustments", tags=["Salary Adjustments"])


def _ensure_station_access(db: Session, *, station_id: int, current_user: User, write: bool = False) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if is_master_admin(current_user):
        return station
    if is_head_office_user(current_user):
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        if write:
            require_permission(
                current_user,
                "payroll",
                "create",
                detail="You do not have permission to manage salary adjustments",
            )
        else:
            require_permission(
                current_user,
                "payroll",
                "read",
                detail="You do not have permission to view salary adjustments",
            )
        return station
    require_station_access(current_user, station_id)
    require_permission(
        current_user,
        "payroll",
        "create" if write else "read",
        detail="You do not have permission to access salary adjustments",
    )
    return station


@router.get("/", response_model=list[SalaryAdjustmentResponse])
def list_salary_adjustments(
    station_id: int | None = Query(None),
    user_id: int | None = Query(None),
    employee_profile_id: int | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "payroll", "read", detail="You do not have permission to view salary adjustments")
    query = db.query(SalaryAdjustment)
    if is_master_admin(current_user):
        pass
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        query = query.join(Station, Station.id == SalaryAdjustment.station_id).filter(Station.organization_id == organization_id)
    else:
        station_id = current_user.station_id
    if station_id is not None:
        _ensure_station_access(db, station_id=station_id, current_user=current_user)
        query = query.filter(SalaryAdjustment.station_id == station_id)
    if user_id is not None:
        query = query.filter(SalaryAdjustment.user_id == user_id)
    if employee_profile_id is not None:
        query = query.filter(SalaryAdjustment.employee_profile_id == employee_profile_id)
    return (
        query.order_by(SalaryAdjustment.effective_date.desc(), SalaryAdjustment.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.post("/", response_model=SalaryAdjustmentResponse)
def create_salary_adjustment(
    data: SalaryAdjustmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_station_access(db, station_id=data.station_id, current_user=current_user, write=True)
    if bool(data.user_id) == bool(data.employee_profile_id):
        raise HTTPException(status_code=400, detail="Provide exactly one of user_id or employee_profile_id")
    if data.user_id is not None:
        user = (
            db.query(User)
            .filter(
                User.id == data.user_id,
                User.station_id == data.station_id,
                User.is_active.is_(True),
            )
            .first()
        )
        if not user:
            raise HTTPException(status_code=400, detail="User must belong to the selected station")
    if data.employee_profile_id is not None:
        profile = (
            db.query(EmployeeProfile)
            .filter(
                EmployeeProfile.id == data.employee_profile_id,
                EmployeeProfile.station_id == data.station_id,
                EmployeeProfile.is_active.is_(True),
            )
            .first()
        )
        if not profile:
            raise HTTPException(status_code=400, detail="Employee profile must belong to the selected station")

    adjustment = SalaryAdjustment(
        station_id=data.station_id,
        user_id=data.user_id,
        employee_profile_id=data.employee_profile_id,
        effective_date=data.effective_date,
        impact=data.impact,
        amount=data.amount,
        reason=data.reason,
        notes=data.notes,
        created_by_user_id=current_user.id,
    )
    db.add(adjustment)
    db.commit()
    db.refresh(adjustment)
    return adjustment
