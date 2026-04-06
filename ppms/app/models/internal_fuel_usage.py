from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class InternalFuelUsage(Base):
    __tablename__ = "internal_fuel_usage"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=False, index=True)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False, index=True)
    quantity = Column(Float, nullable=False)
    purpose = Column(String, nullable=False)
    notes = Column(String, nullable=True)
    used_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, nullable=False, default=utc_now, index=True)

    station = relationship("Station")
    tank = relationship("Tank")
    fuel_type = relationship("FuelType")
    used_by = relationship("User")
