from sqlalchemy import Column, Integer, Float, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime

from app.models.base import Base


class TankDip(Base):
    __tablename__ = "tank_dips"

    id = Column(Integer, primary_key=True, index=True)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=False)
    
    # Manual stick reading in mm
    dip_reading_mm = Column(Float, nullable=False)
    
    # Volume calculated from dip reading (usually via a calibration chart)
    calculated_volume = Column(Float, nullable=False)
    
    # System volume at the time of dip (current_volume in Tank model)
    system_volume = Column(Float, nullable=False)
    
    # Difference = calculated_volume - system_volume
    # Positive means surplus (gain), negative means loss (evaporation/leakage)
    loss_gain = Column(Float, nullable=False)
    
    notes = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    tank = relationship("Tank")
