from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.tanker import Tanker
from app.models.tanker_trip import TankerTrip
from app.models.user import User
from app.schemas.tanker import (
    TankerCreate,
    TankerDeliveryCreate,
    TankerResponse,
    TankerTripComplete,
    TankerTripCreate,
    TankerTripExpenseCreate,
    TankerTripResponse,
    TankerUpdate,
)
from app.services.station_modules import require_station_module_enabled
from app.services.tanker_ops import (
    MODULE_NAME,
    add_trip_delivery,
    add_trip_expense,
    complete_trip,
    create_tanker,
    create_trip,
    update_tanker,
)

router = APIRouter(prefix="/tankers", tags=["Tankers"])


def _ensure_tanker_access(tanker: Tanker, current_user: User) -> None:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return
    if current_user.role.name == "HeadOffice":
        user_organization_id = current_user.station.organization_id if current_user.station else None
        if tanker.station.organization_id == user_organization_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")
    if current_user.station_id != tanker.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")


def _ensure_trip_access(trip: TankerTrip, current_user: User) -> None:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return
    if current_user.role.name == "HeadOffice":
        user_organization_id = current_user.station.organization_id if current_user.station else None
        if trip.station.organization_id == user_organization_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this trip")
    if current_user.station_id != trip.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this trip")


@router.post("/trips", response_model=TankerTripResponse)
def create_trip_route(
    data: TankerTripCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "trip_create", detail="You do not have permission to create tanker trips")
    return create_trip(db, data, current_user)


@router.get("/trips", response_model=list[TankerTripResponse])
def list_trips(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    trip_type: str | None = Query(None),
    status: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "read", detail="You do not have permission to view tanker trips")
    query = db.query(TankerTrip)
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        pass
    elif current_user.role.name == "HeadOffice":
        user_organization_id = current_user.station.organization_id if current_user.station else None
        query = query.join(TankerTrip.station).filter(TankerTrip.station.has(organization_id=user_organization_id))
    else:
        station_id = current_user.station_id
    if station_id:
        query = query.filter(TankerTrip.station_id == station_id)
    if trip_type:
        query = query.filter(TankerTrip.trip_type == trip_type)
    if status:
        query = query.filter(TankerTrip.status == status)
    return query.offset(skip).limit(limit).all()


@router.get("/trips/{trip_id}", response_model=TankerTripResponse)
def get_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "read", detail="You do not have permission to view tanker trips")
    trip = db.query(TankerTrip).filter(TankerTrip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Tanker trip not found")
    _ensure_trip_access(trip, current_user)
    require_station_module_enabled(db, trip.station_id, MODULE_NAME)
    return trip


@router.post("/trips/{trip_id}/deliveries", response_model=TankerTripResponse)
def add_delivery(
    trip_id: int,
    data: TankerDeliveryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "delivery_create", detail="You do not have permission to add tanker deliveries")
    trip = db.query(TankerTrip).filter(TankerTrip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Tanker trip not found")
    return add_trip_delivery(db, trip, data, current_user)


@router.post("/trips/{trip_id}/expenses", response_model=TankerTripResponse)
def add_expense(
    trip_id: int,
    data: TankerTripExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "expense_create", detail="You do not have permission to add tanker trip expenses")
    trip = db.query(TankerTrip).filter(TankerTrip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Tanker trip not found")
    return add_trip_expense(db, trip, data, current_user)


@router.post("/trips/{trip_id}/complete", response_model=TankerTripResponse)
def complete_trip_route(
    trip_id: int,
    data: TankerTripComplete,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "complete", detail="You do not have permission to complete tanker trips")
    trip = db.query(TankerTrip).filter(TankerTrip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Tanker trip not found")
    return complete_trip(db, trip, current_user)


@router.post("/", response_model=TankerResponse)
def create_tanker_route(
    data: TankerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "create", detail="You do not have permission to create tankers")
    return create_tanker(db, data, current_user)


@router.get("/", response_model=list[TankerResponse])
def list_tankers(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    status: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "read", detail="You do not have permission to view tankers")
    query = db.query(Tanker)
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        pass
    elif current_user.role.name == "HeadOffice":
        user_organization_id = current_user.station.organization_id if current_user.station else None
        query = query.join(Tanker.station).filter(Tanker.station.has(organization_id=user_organization_id))
    else:
        station_id = current_user.station_id
    if station_id:
        query = query.filter(Tanker.station_id == station_id)
    if status:
        query = query.filter(Tanker.status == status)
    return query.offset(skip).limit(limit).all()


@router.get("/{tanker_id}", response_model=TankerResponse)
def get_tanker(
    tanker_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "read", detail="You do not have permission to view tankers")
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    _ensure_tanker_access(tanker, current_user)
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    return tanker


@router.put("/{tanker_id}", response_model=TankerResponse)
def update_tanker_route(
    tanker_id: int,
    data: TankerUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "update", detail="You do not have permission to update tankers")
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    _ensure_tanker_access(tanker, current_user)
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    return update_tanker(tanker, data, db)


@router.delete("/{tanker_id}")
def delete_tanker(
    tanker_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "delete", detail="You do not have permission to delete tankers")
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    _ensure_tanker_access(tanker, current_user)
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    if db.query(TankerTrip).filter(TankerTrip.tanker_id == tanker.id).first():
        raise HTTPException(status_code=400, detail="Tanker cannot be deleted while trip history exists")
    db.delete(tanker)
    db.commit()
    return {"message": "Tanker deleted"}
