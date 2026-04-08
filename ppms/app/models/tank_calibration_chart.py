from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class TankCalibrationChart(Base):
    __tablename__ = "tank_calibration_charts"

    id = Column(Integer, primary_key=True, index=True)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=False, index=True)
    version_no = Column(Integer, nullable=False, default=1)
    source_type = Column(String, nullable=False, default="manual")
    document_reference = Column(String, nullable=True)
    notes = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    tank = relationship("Tank")
    lines = relationship(
        "TankCalibrationChartLine",
        back_populates="chart",
        cascade="all, delete-orphan",
    )
