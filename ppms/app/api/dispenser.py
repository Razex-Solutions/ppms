from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.dispenser import Dispenser
from app.models.nozzle import Nozzle
from app.models.station import Station
from app.models.user import User
from app.schemas.dispenser import DispenserCreate, DispenserUpdate, DispenserResponse

router = APIRouter(prefix="/dispensers", tags=["Dispensers"])


def _require_dispenser_station_access(current_user: User, dispenser: Dispenser, db: Session, detail: str = "Not authorized for this dispenser") -> None:
    if is_head_office_user(current_user):
        station = db.query(Station).filter(Station.id == dispenser.station_id).first()
        if station and station.organization_id == get_user_organization_id(current_user):
            return
    require_station_access(current_user, dispenser.station_id, detail=detail)


def _next_dispenser_index(db: Session, station_id: int) -> int:
    return db.query(Dispenser).filter(Dispenser.station_id == station_id).count() + 1


@router.post("/", response_model=DispenserResponse)
def create_dispenser(
    dispenser_data: DispenserCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    require_permission(current_user, "dispensers", "create", detail="You do not have permission to create dispensers")

    station = db.query(Station).filter(Station.id == dispenser_data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if is_head_office_user(current_user):
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this station")
    else:
        require_station_access(current_user, dispenser_data.station_id)

    dispenser_index = _next_dispenser_index(db, dispenser_data.station_id)
    generated_name = dispenser_data.name or f"Dispenser {dispenser_index}"
    generated_code = dispenser_data.code or f"{station.code}-D{dispenser_index}"
    existing = db.query(Dispenser).filter(Dispenser.code == generated_code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Dispenser code already exists")

    dispenser = Dispenser(
        name=generated_name,
        code=generated_code,
        location=dispenser_data.location,
        is_active=dispenser_data.is_active,
        station_id=dispenser_data.station_id,
    )
    db.add(dispenser)
    db.commit()
    db.refresh(dispenser)
    return dispenser


@router.get("/", response_model=list[DispenserResponse])
def list_dispensers(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if is_head_office_user(current_user):
        user_organization_id = get_user_organization_id(current_user)
        query = db.query(Dispenser).join(Station, Station.id == Dispenser.station_id).filter(Station.organization_id == user_organization_id)
        if station_id is not None:
            query = query.filter(Dispenser.station_id == station_id)
    elif not is_master_admin(current_user):
        station_id = current_user.station_id
        query = db.query(Dispenser)
        if station_id:
            query = query.filter(Dispenser.station_id == station_id)
    else:
        query = db.query(Dispenser)
        if station_id:
            query = query.filter(Dispenser.station_id == station_id)
    if not include_inactive:
        query = query.filter(Dispenser.is_active.is_(True))
    return query.offset(skip).limit(limit).all()


@router.get("/{dispenser_id}", response_model=DispenserResponse)
def get_dispenser(
    dispenser_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    dispenser = db.query(Dispenser).filter(Dispenser.id == dispenser_id).first()
    if not dispenser:
        raise HTTPException(status_code=404, detail="Dispenser not found")

    require_permission(current_user, "dispensers", "read", detail="You do not have permission to view dispensers")
    _require_dispenser_station_access(current_user, dispenser, db, detail="Not authorized for this dispenser")
    return dispenser


@router.put("/{dispenser_id}", response_model=DispenserResponse)
def update_dispenser(
    dispenser_id: int,
    data: DispenserUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    dispenser = db.query(Dispenser).filter(Dispenser.id == dispenser_id).first()
    if not dispenser:
        raise HTTPException(status_code=404, detail="Dispenser not found")

    require_permission(current_user, "dispensers", "update", detail="You do not have permission to update dispensers")
    _require_dispenser_station_access(current_user, dispenser, db, detail="Not authorized for this dispenser")

    updates = data.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(dispenser, field, value)
    if updates.get("is_active") is False:
        db.query(Nozzle).filter(Nozzle.dispenser_id == dispenser.id).update({"is_active": False}, synchronize_session=False)
    db.commit()
    db.refresh(dispenser)
    return dispenser


@router.delete("/{dispenser_id}")
def delete_dispenser(
    dispenser_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    dispenser = db.query(Dispenser).filter(Dispenser.id == dispenser_id).first()
    if not dispenser:
        raise HTTPException(status_code=404, detail="Dispenser not found")

    require_permission(current_user, "dispensers", "delete", detail="You do not have permission to delete dispensers")
    _require_dispenser_station_access(current_user, dispenser, db, detail="Not authorized for this dispenser")
    existing_nozzle = db.query(Nozzle).filter(Nozzle.dispenser_id == dispenser.id).first()
    if existing_nozzle:
        dispenser.is_active = False
        db.query(Nozzle).filter(Nozzle.dispenser_id == dispenser.id).update({"is_active": False}, synchronize_session=False)
        db.commit()
        return {"message": "Dispenser deactivated because nozzles are assigned to it", "action": "deactivated"}

    db.delete(dispenser)
    db.commit()
    return {"message": "Dispenser deleted"}
