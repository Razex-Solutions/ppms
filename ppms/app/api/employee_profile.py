from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.employee_profile import EmployeeProfile
from app.models.station import Station
from app.models.user import User
from app.schemas.employee_profile import (
    EmployeeProfileCreate,
    EmployeeProfileResponse,
    EmployeeProfileUpdate,
    SelfEmployeeProfileResponse,
)
from app.services.employee_profiles import create_employee_profile, ensure_employee_profile_access, update_employee_profile


router = APIRouter(prefix="/employee-profiles", tags=["Employee Profiles"])


def _serialize_employee_profile(profile: EmployeeProfile) -> EmployeeProfileResponse:
    linked_user = profile.linked_user
    return EmployeeProfileResponse(
        id=profile.id,
        organization_id=profile.organization_id,
        station_id=profile.station_id,
        linked_user_id=profile.linked_user_id,
        full_name=profile.full_name,
        staff_type=profile.staff_type,
        staff_title=profile.staff_title or profile.staff_type,
        linked_user_role_id=linked_user.role_id if linked_user is not None else None,
        linked_user_role_name=linked_user.role.name if linked_user is not None and linked_user.role is not None else None,
        employee_code=profile.employee_code,
        phone=profile.phone,
        national_id=profile.national_id,
        address=profile.address,
        is_active=profile.is_active,
        payroll_enabled=profile.payroll_enabled,
        monthly_salary=profile.monthly_salary,
        can_login=profile.can_login,
        notes=profile.notes,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )


def _serialize_self_profile(db: Session, current_user: User) -> SelfEmployeeProfileResponse:
    profile = (
        db.query(EmployeeProfile)
        .filter(EmployeeProfile.linked_user_id == current_user.id)
        .first()
    )
    organization = current_user.organization
    station = current_user.station

    return SelfEmployeeProfileResponse(
        user_id=current_user.id,
        username=current_user.username,
        full_name=current_user.full_name,
        role_name=current_user.role.name,
        scope_level=current_user.scope_level,
        email=current_user.email,
        phone=current_user.phone,
        whatsapp_number=current_user.whatsapp_number,
        organization_id=current_user.organization_id,
        organization_name=organization.name if organization is not None else None,
        station_id=current_user.station_id,
        station_name=station.name if station is not None else None,
        has_employee_profile=profile is not None,
        linked_employee_profile_id=profile.id if profile is not None else None,
        staff_type=profile.staff_type if profile is not None else None,
        staff_title=(profile.staff_title or profile.staff_type) if profile is not None else None,
        employee_code=profile.employee_code if profile is not None else None,
        national_id=profile.national_id if profile is not None else None,
        address=profile.address if profile is not None else None,
        is_active=bool(profile.is_active) if profile is not None else bool(current_user.is_active),
        payroll_enabled=bool(profile.payroll_enabled) if profile is not None else bool(current_user.payroll_enabled),
        monthly_salary=float(profile.monthly_salary) if profile is not None else float(current_user.monthly_salary or 0.0),
        can_login=bool(profile.can_login) if profile is not None else True,
    )


@router.post("/", response_model=EmployeeProfileResponse)
def post_employee_profile(
    data: EmployeeProfileCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "employee_profiles", "create", detail="You do not have permission to create employee profiles")
    return _serialize_employee_profile(create_employee_profile(db, data=data, current_user=current_user))


@router.get("/", response_model=list[EmployeeProfileResponse])
def list_employee_profiles(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    staff_type: str | None = Query(None),
    is_active: bool | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "employee_profiles", "read", detail="You do not have permission to view employee profiles")
    query = db.query(EmployeeProfile)
    if is_master_admin(current_user):
        if organization_id is not None:
            query = query.filter(EmployeeProfile.organization_id == organization_id)
    elif is_head_office_user(current_user):
        current_org_id = get_user_organization_id(current_user)
        query = query.filter(EmployeeProfile.organization_id == current_org_id)
        if organization_id is not None and organization_id != current_org_id:
            raise HTTPException(status_code=403, detail="Not authorized for this organization")
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != current_org_id:
                raise HTTPException(status_code=403, detail="Not authorized for this station")
    else:
        station_id = current_user.station_id
    if station_id is not None:
        query = query.filter(EmployeeProfile.station_id == station_id)
    if staff_type is not None:
        query = query.filter(EmployeeProfile.staff_type == staff_type)
    if is_active is not None:
        query = query.filter(EmployeeProfile.is_active == is_active)
    return [
        _serialize_employee_profile(profile)
        for profile in query.order_by(EmployeeProfile.full_name.asc(), EmployeeProfile.id.asc()).offset(skip).limit(limit).all()
    ]


@router.get("/me", response_model=SelfEmployeeProfileResponse)
def get_my_employee_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _serialize_self_profile(db, current_user)


@router.get("/{profile_id}", response_model=EmployeeProfileResponse)
def get_employee_profile(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "employee_profiles", "read", detail="You do not have permission to view employee profiles")
    profile = db.query(EmployeeProfile).filter(EmployeeProfile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Employee profile not found")
    ensure_employee_profile_access(db, profile.station_id, current_user)
    return _serialize_employee_profile(profile)


@router.put("/{profile_id}", response_model=EmployeeProfileResponse)
def put_employee_profile(
    profile_id: int,
    data: EmployeeProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "employee_profiles", "update", detail="You do not have permission to update employee profiles")
    profile = db.query(EmployeeProfile).filter(EmployeeProfile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Employee profile not found")
    return _serialize_employee_profile(update_employee_profile(db, profile=profile, data=data, current_user=current_user))


@router.delete("/{profile_id}")
def delete_employee_profile(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "employee_profiles", "delete", detail="You do not have permission to delete employee profiles")
    profile = db.query(EmployeeProfile).filter(EmployeeProfile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Employee profile not found")
    ensure_employee_profile_access(db, profile.station_id, current_user)
    db.delete(profile)
    db.commit()
    return {"message": "Employee profile deleted"}
