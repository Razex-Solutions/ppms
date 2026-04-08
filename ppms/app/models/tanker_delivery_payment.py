from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class TankerDeliveryPayment(Base):
    __tablename__ = "tanker_delivery_payments"

    id = Column(Integer, primary_key=True, index=True)
    delivery_id = Column(Integer, ForeignKey("tanker_deliveries.id"), nullable=False, index=True)
    amount = Column(Float, nullable=False)
    payment_method = Column(String, nullable=True)
    reference_no = Column(String, nullable=True)
    notes = Column(String, nullable=True)
    received_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    received_at = Column(DateTime, nullable=False, default=utc_now)

    delivery = relationship("TankerDelivery", back_populates="payments")
    received_by_user = relationship("User")
