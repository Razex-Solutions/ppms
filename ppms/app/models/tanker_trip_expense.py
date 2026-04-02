from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class TankerTripExpense(Base):
    __tablename__ = "tanker_trip_expenses"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("tanker_trips.id"), nullable=False, index=True)
    expense_type = Column(String, nullable=False, index=True)
    amount = Column(Float, nullable=False)
    notes = Column(String, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    trip = relationship("TankerTrip", back_populates="expenses")
