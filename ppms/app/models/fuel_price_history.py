from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class FuelPriceHistory(Base):
    __tablename__ = "fuel_price_history"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False, index=True)
    price = Column(Float, nullable=False, default=0.0)
    effective_at = Column(DateTime, nullable=False, default=utc_now, index=True)
    reason = Column(String, nullable=False)
    notes = Column(Text, nullable=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    station = relationship("Station")
    fuel_type = relationship("FuelType")
    created_by = relationship("User")
