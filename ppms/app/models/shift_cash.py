from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class ShiftCash(Base):
    __tablename__ = "shift_cash"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=False, unique=True, index=True)
    manager_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    opening_cash = Column(Float, nullable=False, default=0.0)
    cash_sales = Column(Float, nullable=False, default=0.0)
    expected_cash = Column(Float, nullable=False, default=0.0)
    cash_submitted = Column(Float, nullable=False, default=0.0)
    closing_cash = Column(Float, nullable=True)
    difference = Column(Float, nullable=True)
    notes = Column(String, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    shift = relationship("Shift", back_populates="shift_cash")
    manager = relationship("User")
    submissions = relationship(
        "CashSubmission",
        back_populates="shift_cash",
        cascade="all, delete-orphan",
    )
