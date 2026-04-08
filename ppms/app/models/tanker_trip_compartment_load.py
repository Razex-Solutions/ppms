from sqlalchemy import Column, Float, ForeignKey, Integer
from sqlalchemy.orm import relationship

from app.models.base import Base


class TankerTripCompartmentLoad(Base):
    __tablename__ = "tanker_trip_compartment_loads"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("tanker_trips.id"), nullable=False, index=True)
    compartment_id = Column(Integer, ForeignKey("tanker_compartments.id"), nullable=False, index=True)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False, index=True)
    loaded_quantity = Column(Float, nullable=False)
    remaining_quantity = Column(Float, nullable=False)
    purchase_rate = Column(Float, nullable=False)
    purchase_total = Column(Float, nullable=False)

    trip = relationship("TankerTrip", back_populates="compartment_loads")
    compartment = relationship("TankerCompartment")
    fuel_type = relationship("FuelType")
    deliveries = relationship("TankerDelivery", back_populates="compartment_load")
