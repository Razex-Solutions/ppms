from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class CashSubmission(Base):
    __tablename__ = "cash_submissions"

    id = Column(Integer, primary_key=True, index=True)
    shift_cash_id = Column(Integer, ForeignKey("shift_cash.id"), nullable=False, index=True)
    amount = Column(Float, nullable=False, default=0.0)
    submitted_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    submitted_at = Column(DateTime, nullable=False, default=utc_now)
    notes = Column(String, nullable=True)

    shift_cash = relationship("ShiftCash", back_populates="submissions")
    submitted_by_user = relationship("User")
