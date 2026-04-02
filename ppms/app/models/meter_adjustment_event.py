from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class MeterAdjustmentEvent(Base):
    __tablename__ = "meter_adjustment_events"

    id = Column(Integer, primary_key=True, index=True)
    nozzle_id = Column(Integer, ForeignKey("nozzles.id"), nullable=False, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    old_reading = Column(Float, nullable=False)
    new_reading = Column(Float, nullable=False)
    reason = Column(String, nullable=False)
    adjusted_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    adjusted_at = Column(DateTime, nullable=False, default=utc_now, index=True)

    nozzle = relationship("Nozzle")
    station = relationship("Station")
    adjusted_by = relationship("User")
