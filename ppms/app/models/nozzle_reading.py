from sqlalchemy import Column, Integer, Float, ForeignKey, DateTime, String
from sqlalchemy.orm import relationship
from app.models.base import Base
from app.core.time import utc_now


class NozzleReading(Base):
    __tablename__ = "nozzle_readings"

    id = Column(Integer, primary_key=True, index=True)
    nozzle_id = Column(Integer, ForeignKey("nozzles.id"), nullable=False)
    reading = Column(Float, nullable=False)
    sale_id = Column(Integer, ForeignKey("fuel_sales.id"), nullable=True)
    shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=True, index=True)
    reading_type = Column(String, nullable=False, default="sale", index=True)
    created_at = Column(DateTime, default=utc_now)

    nozzle = relationship("Nozzle", back_populates="readings")
    sale = relationship("FuelSale")
    shift = relationship("Shift", back_populates="nozzle_readings")
