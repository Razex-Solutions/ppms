from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String

from app.core.time import utc_now
from app.models.base import Base


class CustomerCreditIssue(Base):
    __tablename__ = "customer_credit_issues"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=True, index=True)
    amount = Column(Float, nullable=False)
    notes = Column(String, nullable=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utc_now, nullable=False, index=True)
