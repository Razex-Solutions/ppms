from sqlalchemy import Column, Integer, Float, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship

from app.models.base import Base
from app.core.time import utc_now


class Shift(Base):
    __tablename__ = "shifts"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    start_time = Column(DateTime, default=utc_now)
    end_time = Column(DateTime, nullable=True)
    
    status = Column(String, default="open")  # open / closed
    
    initial_cash = Column(Float, default=0.0)
    total_sales_cash = Column(Float, default=0.0)
    total_sales_credit = Column(Float, default=0.0)
    expected_cash = Column(Float, default=0.0)
    actual_cash_collected = Column(Float, nullable=True)
    difference = Column(Float, nullable=True)
    
    notes = Column(String, nullable=True)

    station = relationship("Station")
    user = relationship("User")
    fuel_sales = relationship("FuelSale", back_populates="shift")
