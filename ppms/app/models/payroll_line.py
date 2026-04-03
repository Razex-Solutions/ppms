from sqlalchemy import Column, Float, ForeignKey, Integer
from sqlalchemy.orm import relationship

from app.models.base import Base


class PayrollLine(Base):
    __tablename__ = "payroll_lines"

    id = Column(Integer, primary_key=True, index=True)
    payroll_run_id = Column(Integer, ForeignKey("payroll_runs.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    present_days = Column(Integer, nullable=False, default=0)
    leave_days = Column(Integer, nullable=False, default=0)
    absent_days = Column(Integer, nullable=False, default=0)
    payable_days = Column(Integer, nullable=False, default=0)
    monthly_salary = Column(Float, nullable=False, default=0.0)
    gross_amount = Column(Float, nullable=False, default=0.0)
    deductions = Column(Float, nullable=False, default=0.0)
    net_amount = Column(Float, nullable=False, default=0.0)

    payroll_run = relationship("PayrollRun", back_populates="lines")
    user = relationship("User")
