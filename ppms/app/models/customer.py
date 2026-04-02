from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
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
    credit_override_status = Column(String, nullable=True, index=True)
    credit_override_amount = Column(Float, default=0)
    credit_override_requested_amount = Column(Float, default=0)
    credit_override_requested_at = Column(DateTime, nullable=True)
    credit_override_requested_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    credit_override_reason = Column(String, nullable=True)
    credit_override_reviewed_at = Column(DateTime, nullable=True)
    credit_override_reviewed_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    credit_override_rejection_reason = Column(String, nullable=True)

    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)

    station = relationship("Station")
