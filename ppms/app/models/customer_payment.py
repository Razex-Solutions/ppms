from sqlalchemy import Column, Integer, Float, String, ForeignKey, DateTime, Boolean
from datetime import datetime

from app.models.base import Base


class CustomerPayment(Base):
    __tablename__ = "customer_payments"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)

    amount = Column(Float, nullable=False)
    payment_method = Column(String, default="cash")  # cash / bank / online
    reference_no = Column(String, nullable=True)
    notes = Column(String, nullable=True)
    is_reversed = Column(Boolean, default=False, nullable=False)
    reversed_at = Column(DateTime, nullable=True)
    reversed_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
