from sqlalchemy import Boolean, Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base


class Tank(Base):
    __tablename__ = "tanks"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, unique=True, nullable=False, index=True)
    capacity = Column(Float, nullable=False)
    current_volume = Column(Float, default=0)
    low_stock_threshold = Column(Float, default=1000) # Default 1000 liters
    location = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False)

    station = relationship("Station")
    fuel_type = relationship("FuelType", back_populates="tanks")
