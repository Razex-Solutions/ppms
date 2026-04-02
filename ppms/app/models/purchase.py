from sqlalchemy import Column, Integer, Float, ForeignKey, DateTime, String, Boolean
from sqlalchemy.orm import relationship
from app.models.base import Base
from app.core.time import utc_now


class Purchase(Base):
    __tablename__ = "purchases"

    id = Column(Integer, primary_key=True, index=True)

    supplier_id = Column(Integer, ForeignKey("suppliers.id"), nullable=False)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=False)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False)
    tanker_id = Column(Integer, ForeignKey("tankers.id"), nullable=True)

    quantity = Column(Float, nullable=False)
    rate_per_liter = Column(Float, nullable=False)
    total_amount = Column(Float, nullable=False)

    reference_no = Column(String, nullable=True)
    notes = Column(String, nullable=True)
    status = Column(String, nullable=False, default="pending", index=True)
    submitted_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_at = Column(DateTime, nullable=True)
    rejected_at = Column(DateTime, nullable=True)
    rejection_reason = Column(String, nullable=True)
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

    tank = relationship("Tank")
