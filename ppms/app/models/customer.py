from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base


class Customer(Base):
    __tablename__ = "customers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    code = Column(String, unique=True, nullable=False, index=True)
    customer_type = Column(String, default="individual")  # individual/company/vehicle
    phone = Column(String, nullable=True)
    address = Column(String, nullable=True)
    credit_limit = Column(Float, default=0)
    outstanding_balance = Column(Float, default=0)

    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)

    station = relationship("Station")