from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.employee_profile import EmployeeProfile
from app.models.payroll_line import PayrollLine
from app.models.payroll_run import PayrollRun
from app.models.station import Station
from app.models.user import User
from app.schemas.payroll import (
    PayrollFinalizeRequest,
    PayrollLineResponse,
    PayrollRunCreate,
    PayrollRunResponse,
    PayrollSelfServicePeriodSummary,
    PayrollSelfServiceSummaryResponse,
)
from app.services.payroll import create_payroll_run, ensure_payroll_access, finalize_payroll_run


router = APIRouter(prefix="/payroll", tags=["Payroll"])


def _serialize_self_service_line(line: PayrollLine) -> PayrollSelfServicePeriodSummary:
    return PayrollSelfServicePeriodSummary(
        payroll_run_id=line.payroll_run_id,
        period_start=line.payroll_run.period_start,
        period_end=line.payroll_run.period_end,
        status=line.payroll_run.status,
        monthly_salary=float(line.monthly_salary),
        gross_amount=float(line.gross_amount),
        attendance_deductions=float(line.attendance_deductions),
        adjustment_additions=float(line.adjustment_additions),
        adjustment_deductions=float(line.adjustment_deductions),
        deductions=float(line.deductions),
        net_amount=float(line.net_amount),
    )


@router.get("/my-summary", response_model=PayrollSelfServiceSummaryResponse)
def get_my_payroll_summary(
    limit: int = Query(6, ge=1, le=24),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = (
        db.query(EmployeeProfile)
        .filter(EmployeeProfile.linked_user_id == current_user.id)
        .first()
    )

    query = (
        db.query(PayrollLine)
        .join(PayrollRun, PayrollRun.id == PayrollLine.payroll_run_id)
        .filter(
            or_(
                PayrollLine.user_id == current_user.id,
                PayrollLine.employee_profile_id == (profile.id if profile is not None else -1),
            ),
            PayrollRun.status != "draft",
        )
        .order_by(PayrollRun.period_end.desc(), PayrollRun.id.desc(), PayrollLine.id.desc())
    )
    lines = query.limit(limit).all()
    history = [_serialize_self_service_line(line) for line in lines]

    enabled = bool((profile.payroll_enabled if profile is not None else current_user.payroll_enabled))
    current_monthly_salary = float(profile.monthly_salary) if profile is not None else float(current_user.monthly_salary or 0.0)

    return PayrollSelfServiceSummaryResponse(
        enabled=enabled,
        current_monthly_salary=current_monthly_salary,
        latest_run=history[0] if history else None,
        history=history,
    )


@router.post("/runs", response_model=PayrollRunResponse)
def post_payroll_run(
    data: PayrollRunCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "payroll", "create", detail="You do not have permission to create payroll runs")
    return create_payroll_run(db, data=data, current_user=current_user)


@router.get("/runs", response_model=list[PayrollRunResponse])
def list_payroll_runs(
    station_id: int | None = Query(None),
    status: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "payroll", "read", detail="You do not have permission to view payroll")
    query = db.query(PayrollRun)
    if is_master_admin(current_user):
        pass
    elif current_user.role.name == "HeadOffice":
        organization_id = get_user_organization_id(current_user)
        query = query.join(Station, Station.id == PayrollRun.station_id).filter(Station.organization_id == organization_id)
    else:
        station_id = current_user.station_id
    if station_id is not None:
        query = query.filter(PayrollRun.station_id == station_id)
    if status is not None:
        query = query.filter(PayrollRun.status == status)
    return query.order_by(PayrollRun.created_at.desc(), PayrollRun.id.desc()).offset(skip).limit(limit).all()


@router.get("/runs/{payroll_run_id}", response_model=PayrollRunResponse)
def get_payroll_run(
    payroll_run_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "payroll", "read", detail="You do not have permission to view payroll")
    payroll_run = db.query(PayrollRun).filter(PayrollRun.id == payroll_run_id).first()
    if not payroll_run:
        raise HTTPException(status_code=404, detail="Payroll run not found")
    ensure_payroll_access(db, payroll_run.station_id, current_user)
    return payroll_run


@router.get("/runs/{payroll_run_id}/lines", response_model=list[PayrollLineResponse])
def list_payroll_lines(
    payroll_run_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "payroll", "read", detail="You do not have permission to view payroll")
    payroll_run = db.query(PayrollRun).filter(PayrollRun.id == payroll_run_id).first()
    if not payroll_run:
        raise HTTPException(status_code=404, detail="Payroll run not found")
    ensure_payroll_access(db, payroll_run.station_id, current_user)
    return payroll_run.lines


@router.post("/runs/{payroll_run_id}/finalize", response_model=PayrollRunResponse)
def post_finalize_payroll_run(
    payroll_run_id: int,
    data: PayrollFinalizeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "payroll", "finalize", detail="You do not have permission to finalize payroll")
    payroll_run = db.query(PayrollRun).filter(PayrollRun.id == payroll_run_id).first()
    if not payroll_run:
        raise HTTPException(status_code=404, detail="Payroll run not found")
    return finalize_payroll_run(db, payroll_run=payroll_run, current_user=current_user, notes=data.notes)
