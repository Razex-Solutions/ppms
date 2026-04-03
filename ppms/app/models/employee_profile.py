from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class EmployeeProfile(Base):
    __tablename__ = "employee_profiles"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("organizations.id"), nullable=False, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    linked_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, unique=True, index=True)
    full_name = Column(String, nullable=False, index=True)
    staff_type = Column(String, nullable=False, index=True)
    employee_code = Column(String, nullable=True, index=True)
    phone = Column(String, nullable=True)
    national_id = Column(String, nullable=True)
    address = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    payroll_enabled = Column(Boolean, nullable=False, default=True)
    monthly_salary = Column(Float, nullable=False, default=0.0)
    can_login = Column(Boolean, nullable=False, default=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)
    updated_at = Column(DateTime, nullable=False, default=utc_now, onupdate=utc_now)

    organization = relationship("Organization")
    station = relationship("Station")
    linked_user = relationship("User", foreign_keys=[linked_user_id])
