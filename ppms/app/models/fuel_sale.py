from sqlalchemy import Column, Integer, Float, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from app.models.base import Base
from app.core.time import utc_now


class FuelSale(Base):
    __tablename__ = "fuel_sales"

    id = Column(Integer, primary_key=True, index=True)

    nozzle_id = Column(Integer, ForeignKey("nozzles.id"), nullable=False)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True)

    opening_meter = Column(Float, nullable=False)
    closing_meter = Column(Float, nullable=False)
    quantity = Column(Float, nullable=False)

    rate_per_liter = Column(Float, nullable=False)
    total_amount = Column(Float, nullable=False)

    sale_type = Column(String, default="cash")   # cash / credit
    shift_name = Column(String, nullable=True)
    shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=True)
    is_reversed = Column(Boolean, default=False, nullable=False)
    reversed_at = Column(DateTime, nullable=True)
    reversed_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    created_at = Column(DateTime, default=utc_now)

    nozzle = relationship("Nozzle")
    station = relationship("Station")
    fuel_type = relationship("FuelType")
    customer = relationship("Customer")
    shift = relationship("Shift", back_populates="fuel_sales")
