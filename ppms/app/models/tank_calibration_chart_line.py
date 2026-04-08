from sqlalchemy import Column, Float, ForeignKey, Integer
from sqlalchemy.orm import relationship

from app.models.base import Base


class TankCalibrationChartLine(Base):
    __tablename__ = "tank_calibration_chart_lines"

    id = Column(Integer, primary_key=True, index=True)
    chart_id = Column(Integer, ForeignKey("tank_calibration_charts.id"), nullable=False, index=True)
    dip_mm = Column(Float, nullable=False)
    volume_liters = Column(Float, nullable=False)
    water_mm = Column(Float, nullable=True)
    sort_order = Column(Integer, nullable=False, default=0)

    chart = relationship("TankCalibrationChart", back_populates="lines")
