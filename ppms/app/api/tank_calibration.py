from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.tank import Tank
from app.models.tank_calibration_chart import TankCalibrationChart
from app.models.user import User
from app.schemas.tank_calibration import (
    TankCalibrationChartCreate,
    TankCalibrationChartResponse,
    TankCalibrationChartUpdate,
)
from app.services.tank_calibrations import (
    create_tank_calibration_chart,
    update_tank_calibration_chart,
)

router = APIRouter(prefix="/tank-calibrations", tags=["Tank Calibrations"])


@router.post("/", response_model=TankCalibrationChartResponse)
def create_chart(
    data: TankCalibrationChartCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tanks", "update", detail="You do not have permission to manage calibration charts")
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    require_station_access(current_user, tank.station_id, detail="Not authorized for this tank")
    return create_tank_calibration_chart(db, payload=data, current_user=current_user)


@router.get("/", response_model=list[TankCalibrationChartResponse])
def list_charts(
    tank_id: int = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tank = db.query(Tank).filter(Tank.id == tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    require_station_access(current_user, tank.station_id, detail="Not authorized for this tank")
    return (
        db.query(TankCalibrationChart)
        .filter(TankCalibrationChart.tank_id == tank_id)
        .order_by(TankCalibrationChart.version_no.desc(), TankCalibrationChart.id.desc())
        .all()
    )


@router.get("/{chart_id}", response_model=TankCalibrationChartResponse)
def get_chart(
    chart_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chart = db.query(TankCalibrationChart).filter(TankCalibrationChart.id == chart_id).first()
    if not chart:
        raise HTTPException(status_code=404, detail="Calibration chart not found")
    require_station_access(current_user, chart.tank.station_id, detail="Not authorized for this chart")
    return chart


@router.put("/{chart_id}", response_model=TankCalibrationChartResponse)
def update_chart(
    chart_id: int,
    data: TankCalibrationChartUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "tanks", "update", detail="You do not have permission to manage calibration charts")
    chart = db.query(TankCalibrationChart).filter(TankCalibrationChart.id == chart_id).first()
    if not chart:
        raise HTTPException(status_code=404, detail="Calibration chart not found")
    require_station_access(current_user, chart.tank.station_id, detail="Not authorized for this chart")
    return update_tank_calibration_chart(db, chart=chart, payload=data)
