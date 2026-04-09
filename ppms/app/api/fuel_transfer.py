from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.fuel_transfer import FuelTransfer
from app.models.station import Station
from app.models.user import User
from app.schemas.tanker import FuelTransferResponse

router = APIRouter(prefix="/fuel-transfers", tags=["Fuel transfers"])


@router.get("/", response_model=list[FuelTransferResponse])
def list_fuel_transfers(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    transfer_type: str | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tankers", "read", detail="You do not have permission to view fuel transfers")

    query = db.query(FuelTransfer)
    if is_master_admin(current_user):
        pass
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
    else:
        station_id = current_user.station_id

    if station_id is not None:
        query = query.filter(FuelTransfer.station_id == station_id)
    elif organization_id is not None:
        query = query.join(Station, Station.id == FuelTransfer.station_id).filter(
            Station.organization_id == organization_id,
        )

    if transfer_type:
        query = query.filter(FuelTransfer.transfer_type == transfer_type)
    if from_date:
        query = query.filter(FuelTransfer.created_at >= from_date)
    if to_date:
        query = query.filter(FuelTransfer.created_at < to_date)

    return query.order_by(FuelTransfer.created_at.desc(), FuelTransfer.id.desc()).offset(skip).limit(limit).all()
