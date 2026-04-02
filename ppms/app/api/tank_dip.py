from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.tank_dip import TankDip
from app.models.tank import Tank
from app.schemas.tank_dip import TankDipCreate, TankDipResponse

router = APIRouter(prefix="/tank-dips", tags=["Tank Dips"])


@router.post("/", response_model=TankDipResponse)
def create_tank_dip(
    data: TankDipCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank")

    system_volume = tank.current_volume
    loss_gain = data.calculated_volume - system_volume

    dip = TankDip(
        tank_id=data.tank_id,
        dip_reading_mm=data.dip_reading_mm,
        calculated_volume=data.calculated_volume,
        system_volume=system_volume,
        loss_gain=loss_gain,
        notes=data.notes
    )

    db.add(dip)
    
    # We update the system volume to match the manual reading (reconciliation)
    tank.current_volume = data.calculated_volume
    
    db.commit()
    db.refresh(dip)
    return dip


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

    # Multi-tenancy check
    if current_user.role.name != "Admin" and current_user.station_id != dip.tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank dip")

    return dip
