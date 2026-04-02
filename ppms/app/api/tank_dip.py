from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.tank_dip import TankDip
from app.models.tank import Tank
from app.schemas.tank_dip import TankDipCreate, TankDipResponse
from app.services.tank_dips import create_tank_dip as create_tank_dip_service
from app.services.tank_dips import ensure_tank_dip_access

router = APIRouter(prefix="/tank-dips", tags=["Tank Dips"])


@router.post("/", response_model=TankDipResponse)
def create_tank_dip(
    data: TankDipCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    return create_tank_dip_service(db, data, current_user)


@router.get("/", response_model=list[TankDipResponse])
def list_tank_dips(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    tank_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Multi-tenancy check
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(TankDip)
    if station_id:
        q = q.join(Tank).filter(Tank.station_id == station_id)
    if tank_id:
        q = q.filter(TankDip.tank_id == tank_id)
    if from_date:
        q = q.filter(TankDip.created_at >= from_date)
    if to_date:
        q = q.filter(TankDip.created_at < to_date)
        
    return q.order_by(TankDip.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{dip_id}", response_model=TankDipResponse)
def get_tank_dip(
    dip_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    dip = db.query(TankDip).filter(TankDip.id == dip_id).first()
    if not dip:
        raise HTTPException(status_code=404, detail="Tank dip reading not found")

    ensure_tank_dip_access(dip, current_user)

    return dip
