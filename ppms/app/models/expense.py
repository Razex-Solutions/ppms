from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from app.models.base import Base
from app.core.time import utc_now


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    category = Column(String, nullable=False)
    amount = Column(Float, nullable=False)
    notes = Column(String, nullable=True)

    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)
    status = Column(String, nullable=False, default="pending", index=True)
    submitted_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_at = Column(DateTime, nullable=True)
    rejected_at = Column(DateTime, nullable=True)
    rejection_reason = Column(String, nullable=True)

    created_at = Column(DateTime, default=utc_now)
