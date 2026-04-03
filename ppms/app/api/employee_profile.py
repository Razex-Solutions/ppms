from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.employee_profile import EmployeeProfile
from app.models.station import Station
from app.models.user import User
from app.schemas.employee_profile import EmployeeProfileCreate, EmployeeProfileResponse, EmployeeProfileUpdate
from app.services.employee_profiles import create_employee_profile, ensure_employee_profile_access, update_employee_profile


router = APIRouter(prefix="/employee-profiles", tags=["Employee Profiles"])


@router.post("/", response_model=EmployeeProfileResponse)
def post_employee_profile(
    data: EmployeeProfileCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "employee_profiles", "create", detail="You do not have permission to create employee profiles")
    return create_employee_profile(db, data=data, current_user=current_user)


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
    if current_user.role.name in {"MasterAdmin", "Admin"} or current_user.is_platform_user:
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
    return query.order_by(EmployeeProfile.full_name.asc(), EmployeeProfile.id.asc()).offset(skip).limit(limit).all()


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
    return profile


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
    return update_employee_profile(db, profile=profile, data=data, current_user=current_user)


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
