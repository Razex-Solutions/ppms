from sqlalchemy import Column, Integer, Float, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from app.models.base import Base
from app.core.time import utc_now


class SupplierPayment(Base):
    __tablename__ = "supplier_payments"

    id = Column(Integer, primary_key=True, index=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.id"), nullable=False)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)

    amount = Column(Float, nullable=False)
    payment_method = Column(String, default="cash")  # cash / bank / online
    reference_no = Column(String, nullable=True)
    notes = Column(String, nullable=True)
    is_reversed = Column(Boolean, default=False, nullable=False)
    reversal_request_status = Column(String, nullable=True, index=True)
    reversal_requested_at = Column(DateTime, nullable=True)
    reversal_requested_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    reversal_request_reason = Column(String, nullable=True)
    reversal_reviewed_at = Column(DateTime, nullable=True)
    reversal_reviewed_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    reversal_rejection_reason = Column(String, nullable=True)
    reversed_at = Column(DateTime, nullable=True)
    reversed_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    created_at = Column(DateTime, default=utc_now)

    station = relationship("Station")
