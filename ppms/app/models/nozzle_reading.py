from sqlalchemy import Column, Integer, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.models.base import Base
from app.core.time import utc_now


class NozzleReading(Base):
    __tablename__ = "nozzle_readings"

    id = Column(Integer, primary_key=True, index=True)
    nozzle_id = Column(Integer, ForeignKey("nozzles.id"), nullable=False)
    reading = Column(Float, nullable=False)
    sale_id = Column(Integer, ForeignKey("fuel_sales.id"), nullable=True)
    created_at = Column(DateTime, default=utc_now)

    nozzle = relationship("Nozzle")
    sale = relationship("FuelSale")
