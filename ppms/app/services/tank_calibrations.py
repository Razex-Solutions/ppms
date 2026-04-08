from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.tank import Tank
from app.models.tank_calibration_chart import TankCalibrationChart
from app.models.tank_calibration_chart_line import TankCalibrationChartLine
from app.models.user import User
from app.schemas.tank_calibration import (
    TankCalibrationChartCreate,
    TankCalibrationChartLineInput,
    TankCalibrationChartUpdate,
)


def _normalized_lines(lines: list[TankCalibrationChartLineInput]) -> list[TankCalibrationChartLineInput]:
    ordered = sorted(lines, key=lambda item: (item.dip_mm, item.sort_order or 0))
    if len(ordered) < 2:
        raise HTTPException(status_code=400, detail="Calibration chart needs at least 2 lines")
    seen: set[float] = set()
    for item in ordered:
        if item.dip_mm in seen:
            raise HTTPException(status_code=400, detail="Calibration chart cannot contain duplicate dip_mm values")
        seen.add(item.dip_mm)
    return ordered


def _replace_chart_lines(db: Session, chart: TankCalibrationChart, lines: list[TankCalibrationChartLineInput]) -> None:
    ordered = _normalized_lines(lines)
    for line in list(chart.lines):
        db.delete(line)
    db.flush()
    for index, item in enumerate(ordered, start=1):
        db.add(
            TankCalibrationChartLine(
                chart_id=chart.id,
                dip_mm=item.dip_mm,
                volume_liters=item.volume_liters,
                water_mm=item.water_mm,
                sort_order=item.sort_order if item.sort_order is not None else index,
            )
        )
    db.flush()


def create_tank_calibration_chart(
    db: Session,
    *,
    payload: TankCalibrationChartCreate,
    current_user: User,
) -> TankCalibrationChart:
    tank = db.query(Tank).filter(Tank.id == payload.tank_id).first()
    if tank is None:
        raise HTTPException(status_code=404, detail="Tank not found")

    chart = TankCalibrationChart(
        tank_id=payload.tank_id,
        version_no=payload.version_no,
        source_type=payload.source_type,
        document_reference=payload.document_reference,
        notes=payload.notes,
        is_active=payload.is_active,
        created_by_user_id=current_user.id,
    )
    db.add(chart)
    db.flush()
    _replace_chart_lines(db, chart, payload.lines)

    if payload.is_active:
        (
            db.query(TankCalibrationChart)
            .filter(
                TankCalibrationChart.tank_id == payload.tank_id,
                TankCalibrationChart.id != chart.id,
            )
            .update({TankCalibrationChart.is_active: False}, synchronize_session=False)
        )

    db.commit()
    db.refresh(chart)
    return chart


def update_tank_calibration_chart(
    db: Session,
    *,
    chart: TankCalibrationChart,
    payload: TankCalibrationChartUpdate,
) -> TankCalibrationChart:
    if payload.version_no is not None:
        chart.version_no = payload.version_no
    if payload.source_type is not None:
        chart.source_type = payload.source_type
    if payload.document_reference is not None:
        chart.document_reference = payload.document_reference
    if payload.notes is not None:
        chart.notes = payload.notes
    if payload.is_active is not None:
        chart.is_active = payload.is_active
    if payload.lines is not None:
        _replace_chart_lines(db, chart, payload.lines)

    db.flush()
    if chart.is_active:
        (
            db.query(TankCalibrationChart)
            .filter(
                TankCalibrationChart.tank_id == chart.tank_id,
                TankCalibrationChart.id != chart.id,
            )
            .update({TankCalibrationChart.is_active: False}, synchronize_session=False)
        )

    db.commit()
    db.refresh(chart)
    return chart


def get_active_tank_calibration_chart(db: Session, tank_id: int) -> TankCalibrationChart | None:
    return (
        db.query(TankCalibrationChart)
        .filter(
            TankCalibrationChart.tank_id == tank_id,
            TankCalibrationChart.is_active.is_(True),
        )
        .order_by(TankCalibrationChart.version_no.desc(), TankCalibrationChart.id.desc())
        .first()
    )


def calculate_tank_volume_from_dip_mm(db: Session, *, tank_id: int, dip_reading_mm: float) -> float:
    chart = get_active_tank_calibration_chart(db, tank_id)
    if chart is None or len(chart.lines) < 2:
        raise HTTPException(status_code=400, detail="Active calibration chart is required for this tank")

    ordered = sorted(chart.lines, key=lambda item: item.dip_mm)
    if dip_reading_mm < ordered[0].dip_mm or dip_reading_mm > ordered[-1].dip_mm:
        raise HTTPException(status_code=400, detail="Dip reading is outside the active calibration chart range")

    for line in ordered:
        if line.dip_mm == dip_reading_mm:
            return round(float(line.volume_liters), 2)

    lower = None
    upper = None
    for index in range(len(ordered) - 1):
        current_line = ordered[index]
        next_line = ordered[index + 1]
        if current_line.dip_mm <= dip_reading_mm <= next_line.dip_mm:
            lower = current_line
            upper = next_line
            break

    if lower is None or upper is None:
        raise HTTPException(status_code=400, detail="Unable to interpolate dip reading from calibration chart")

    mm_span = upper.dip_mm - lower.dip_mm
    if mm_span == 0:
        return round(float(lower.volume_liters), 2)
    ratio = (dip_reading_mm - lower.dip_mm) / mm_span
    volume = lower.volume_liters + ((upper.volume_liters - lower.volume_liters) * ratio)
    return round(float(volume), 2)
