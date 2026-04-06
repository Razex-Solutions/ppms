from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class FuelTransfer(Base):
    __tablename__ = "fuel_transfers"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=False, index=True)
    tanker_trip_id = Column(Integer, ForeignKey("tanker_trips.id"), nullable=True, index=True)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False, index=True)
    quantity = Column(Float, nullable=False)
    transfer_type = Column(String, nullable=False, default="tanker_leftover_to_tank", index=True)
    notes = Column(String, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    station = relationship("Station")
    tank = relationship("Tank")
    tanker_trip = relationship("TankerTrip", back_populates="fuel_transfers")
    fuel_type = relationship("FuelType")
