from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class TankerTrip(Base):
    __tablename__ = "tanker_trips"

    id = Column(Integer, primary_key=True, index=True)
    tanker_id = Column(Integer, ForeignKey("tankers.id"), nullable=False, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.id"), nullable=True, index=True)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False, index=True)
    trip_type = Column(String, nullable=False, index=True)  # supplier_to_station / supplier_to_customer
    status = Column(String, nullable=False, default="planned", index=True)
    settlement_status = Column(String, nullable=False, default="unpaid", index=True)
    linked_tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=True, index=True)
    linked_purchase_id = Column(Integer, ForeignKey("purchases.id"), nullable=True, index=True)
    transfer_tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=True, index=True)
    destination_name = Column(String, nullable=True)
    notes = Column(String, nullable=True)
    loaded_quantity = Column(Float, nullable=True)
    purchase_rate = Column(Float, nullable=True)
    purchase_total = Column(Float, nullable=False, default=0)
    total_quantity = Column(Float, nullable=False, default=0)
    leftover_quantity = Column(Float, nullable=False, default=0)
    transferred_quantity = Column(Float, nullable=False, default=0)
    fuel_revenue = Column(Float, nullable=False, default=0)
    delivery_revenue = Column(Float, nullable=False, default=0)
    expense_total = Column(Float, nullable=False, default=0)
    net_profit = Column(Float, nullable=False, default=0)
    created_at = Column(DateTime, nullable=False, default=utc_now)
    completed_at = Column(DateTime, nullable=True)

    tanker = relationship("Tanker")
    station = relationship("Station")
    supplier = relationship("Supplier")
    fuel_type = relationship("FuelType")
    linked_tank = relationship("Tank", foreign_keys=[linked_tank_id])
    linked_purchase = relationship("Purchase")
    transfer_tank = relationship("Tank", foreign_keys=[transfer_tank_id])
    deliveries = relationship("TankerDelivery", back_populates="trip", cascade="all, delete-orphan")
    expenses = relationship("TankerTripExpense", back_populates="trip", cascade="all, delete-orphan")
    fuel_transfers = relationship("FuelTransfer", back_populates="tanker_trip", cascade="all, delete-orphan")
