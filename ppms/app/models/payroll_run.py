from sqlalchemy import Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class PayrollRun(Base):
    __tablename__ = "payroll_runs"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    period_start = Column(Date, nullable=False, index=True)
    period_end = Column(Date, nullable=False, index=True)
    status = Column(String, nullable=False, default="draft", index=True)
    total_staff = Column(Integer, nullable=False, default=0)
    total_gross_amount = Column(Float, nullable=False, default=0.0)
    total_deductions = Column(Float, nullable=False, default=0.0)
    total_net_amount = Column(Float, nullable=False, default=0.0)
    notes = Column(Text, nullable=True)
    generated_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    finalized_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    finalized_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)
    updated_at = Column(DateTime, nullable=False, default=utc_now, onupdate=utc_now)

    station = relationship("Station")
    generated_by = relationship("User", foreign_keys=[generated_by_user_id])
    finalized_by = relationship("User", foreign_keys=[finalized_by_user_id])
    lines = relationship("PayrollLine", back_populates="payroll_run")
