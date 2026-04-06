from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Time
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class StationShiftTemplate(Base):
    __tablename__ = "station_shift_templates"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    station = relationship("Station")
    shifts = relationship("Shift", back_populates="shift_template")
