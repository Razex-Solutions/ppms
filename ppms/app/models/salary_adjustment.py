from sqlalchemy import Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class SalaryAdjustment(Base):
    __tablename__ = "salary_adjustments"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    employee_profile_id = Column(Integer, ForeignKey("employee_profiles.id"), nullable=True, index=True)
    effective_date = Column(Date, nullable=False, index=True)
    impact = Column(String, nullable=False, default="addition")
    amount = Column(Float, nullable=False, default=0.0)
    reason = Column(String, nullable=False)
    notes = Column(Text, nullable=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    station = relationship("Station")
    user = relationship("User", foreign_keys=[user_id])
    employee_profile = relationship("EmployeeProfile", foreign_keys=[employee_profile_id])
    created_by = relationship("User", foreign_keys=[created_by_user_id])
