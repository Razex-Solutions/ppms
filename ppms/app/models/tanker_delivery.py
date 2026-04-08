from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class TankerDelivery(Base):
    __tablename__ = "tanker_deliveries"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("tanker_trips.id"), nullable=False, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True, index=True)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False, index=True)
    compartment_load_id = Column(Integer, ForeignKey("tanker_trip_compartment_loads.id"), nullable=True, index=True)
    destination_name = Column(String, nullable=True)
    quantity = Column(Float, nullable=False)
    fuel_rate = Column(Float, nullable=False)
    fuel_amount = Column(Float, nullable=False)
    delivery_charge = Column(Float, nullable=False, default=0)
    sale_type = Column(String, nullable=False, default="cash")
    paid_amount = Column(Float, nullable=False, default=0)
    outstanding_amount = Column(Float, nullable=False, default=0)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    trip = relationship("TankerTrip", back_populates="deliveries")
    customer = relationship("Customer")
    fuel_type = relationship("FuelType")
    compartment_load = relationship("TankerTripCompartmentLoad", back_populates="deliveries")
    payments = relationship("TankerDeliveryPayment", back_populates="delivery", cascade="all, delete-orphan")
