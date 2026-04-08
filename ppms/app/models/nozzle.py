from sqlalchemy import Boolean, Column, Integer, String, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class Nozzle(Base):
    __tablename__ = "nozzles"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, unique=True, nullable=False, index=True)
    meter_reading = Column(Float, default=0)
    current_segment_start_reading = Column(Float, default=0, nullable=False)
    current_segment_started_at = Column(DateTime, default=utc_now, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)

    dispenser_id = Column(Integer, ForeignKey("dispensers.id"), nullable=False)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=False)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False)

    dispenser = relationship("Dispenser", back_populates="nozzles")
    tank = relationship("Tank")
    fuel_type = relationship("FuelType")
    readings = relationship("NozzleReading", back_populates="nozzle")
