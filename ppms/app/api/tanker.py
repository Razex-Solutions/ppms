from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.tanker import Tanker
from app.models.tanker_trip import TankerTrip
from app.models.user import User
from app.schemas.tanker import (
    TankerCreate,
    TankerCompartmentCreate,
    TankerCompartmentResponse,
    TankerCompartmentUpdate,
    TankerDeliveryCreate,
    TankerDeliveryPaymentCreate,
    TankerResponse,
    TankerTripComplete,
    TankerTripCreate,
    TankerTripExpenseCreate,
    TankerTripResponse,
    TankerWorkspaceSummaryResponse,
    TankerUpdate,
)
from app.services.station_modules import require_station_module_enabled
from app.services.tanker_ops import (
    MODULE_NAME,
    add_trip_delivery,
    add_trip_delivery_payment,
    add_trip_expense,
    apply_tanker_scope,
    build_tanker_workspace_summary,
    complete_trip,
    create_compartment,
    create_tanker,
    create_trip,
    update_compartment,
    update_tanker,
)

router = APIRouter(prefix="/tankers", tags=["Tankers"])


def _ensure_tanker_access(tanker: Tanker, current_user: User) -> None:
    if is_master_admin(current_user):
        return
    if is_head_office_user(current_user):
        user_organization_id = get_user_organization_id(current_user)
        if tanker.organization_id == user_organization_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")
    if current_user.station_id != tanker.station_id or tanker.organization_id != get_user_organization_id(current_user):
        raise HTTPException(status_code=403, detail="Not authorized for this tanker")


def _ensure_trip_access(trip: TankerTrip, current_user: User) -> None:
    if is_master_admin(current_user):
        return
    if is_head_office_user(current_user):
        user_organization_id = get_user_organization_id(current_user)
        if trip.organization_id == user_organization_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this trip")
    if current_user.station_id != trip.station_id or trip.organization_id != get_user_organization_id(current_user):
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
    if is_master_admin(current_user):
        pass
    elif is_head_office_user(current_user):
        query = query.filter(TankerTrip.organization_id == get_user_organization_id(current_user))
    else:
        station_id = current_user.station_id
    if station_id:
        query = query.filter(TankerTrip.station_id == station_id)
    if trip_type:
        query = query.filter(TankerTrip.trip_type == trip_type)
    if status:
        query = query.filter(TankerTrip.status == status)
    return query.offset(skip).limit(limit).all()


@router.get("/summary", response_model=TankerWorkspaceSummaryResponse)
def get_tanker_summary(
    station_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "read", detail="You do not have permission to view tanker summaries")
    if station_id is not None:
        tanker_query = db.query(Tanker)
        tanker_query, _, scoped_station_id = apply_tanker_scope(
            tanker_query,
            Tanker,
            current_user,
        )
        effective_station_id = scoped_station_id or station_id
        tanker = tanker_query.filter(Tanker.station_id == effective_station_id).first()
        if tanker is None and scoped_station_id is None:
            station_trip_query = db.query(TankerTrip)
            station_trip_query, _, _ = apply_tanker_scope(
                station_trip_query,
                TankerTrip,
                current_user,
            )
            trip = station_trip_query.filter(TankerTrip.station_id == station_id).first()
            if trip is None:
                raise HTTPException(status_code=403, detail="Not authorized for this station")
        require_station_module_enabled(db, effective_station_id, MODULE_NAME)
    return build_tanker_workspace_summary(db, current_user, station_id=station_id)


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


@router.post("/trips/{trip_id}/deliveries/{delivery_id}/payments", response_model=TankerTripResponse)
def add_delivery_payment(
    trip_id: int,
    delivery_id: int,
    data: TankerDeliveryPaymentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "delivery_create", detail="You do not have permission to record tanker payments")
    trip = db.query(TankerTrip).filter(TankerTrip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Tanker trip not found")
    return add_trip_delivery_payment(db, trip, delivery_id, data, current_user)


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
    return complete_trip(
        db,
        trip,
        current_user,
        transfer_to_tank_id=data.transfer_to_tank_id,
        transfer_quantity=data.transfer_quantity,
    )


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
    if is_master_admin(current_user):
        pass
    elif is_head_office_user(current_user):
        query = query.filter(Tanker.organization_id == get_user_organization_id(current_user))
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


@router.get("/{tanker_id}/compartments", response_model=list[TankerCompartmentResponse])
def list_compartments(
    tanker_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "read", detail="You do not have permission to view tanker compartments")
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    _ensure_tanker_access(tanker, current_user)
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    return tanker.compartments


@router.post("/{tanker_id}/compartments", response_model=TankerCompartmentResponse)
def create_compartment_route(
    tanker_id: int,
    data: TankerCompartmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "update", detail="You do not have permission to manage tanker compartments")
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    _ensure_tanker_access(tanker, current_user)
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    return create_compartment(db, tanker, data)


@router.put("/{tanker_id}/compartments/{compartment_id}", response_model=TankerCompartmentResponse)
def update_compartment_route(
    tanker_id: int,
    compartment_id: int,
    data: TankerCompartmentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "update", detail="You do not have permission to manage tanker compartments")
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    _ensure_tanker_access(tanker, current_user)
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    compartment = next((item for item in tanker.compartments if item.id == compartment_id), None)
    if compartment is None:
        raise HTTPException(status_code=404, detail="Tanker compartment not found")
    return update_compartment(db, tanker, compartment, data)


@router.delete("/{tanker_id}/compartments/{compartment_id}")
def delete_compartment(
    tanker_id: int,
    compartment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "update", detail="You do not have permission to manage tanker compartments")
    tanker = db.query(Tanker).filter(Tanker.id == tanker_id).first()
    if not tanker:
        raise HTTPException(status_code=404, detail="Tanker not found")
    _ensure_tanker_access(tanker, current_user)
    require_station_module_enabled(db, tanker.station_id, MODULE_NAME)
    compartment = next((item for item in tanker.compartments if item.id == compartment_id), None)
    if compartment is None:
        raise HTTPException(status_code=404, detail="Tanker compartment not found")
    db.delete(compartment)
    db.commit()
    return {"message": "Tanker compartment deleted"}
