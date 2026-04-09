from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String

from app.core.time import utc_now
from app.models.base import Base


class CustomerCreditIssue(Base):
    __tablename__ = "customer_credit_issues"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=True, index=True)
    nozzle_id = Column(Integer, ForeignKey("nozzles.id"), nullable=True, index=True)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=True, index=True)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=True, index=True)
    quantity = Column(Float, nullable=True)
    rate_per_liter = Column(Float, nullable=True)
    amount = Column(Float, nullable=False)
    notes = Column(String, nullable=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utc_now, nullable=False, index=True)
