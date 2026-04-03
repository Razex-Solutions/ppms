from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, Float
from sqlalchemy.orm import relationship

from app.models.base import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    username = Column(String, unique=True, nullable=False, index=True)
    email = Column(String, unique=True, nullable=True, index=True)
    phone = Column(String, nullable=True)
    whatsapp_number = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    failed_login_attempts = Column(Integer, nullable=False, default=0)
    last_failed_login_at = Column(DateTime, nullable=True)
    locked_until = Column(DateTime, nullable=True)
    last_login_at = Column(DateTime, nullable=True)
    monthly_salary = Column(Float, nullable=False, default=0.0)
    payroll_enabled = Column(Boolean, nullable=False, default=True)

    role_id = Column(Integer, ForeignKey("roles.id"), nullable=False)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=True)

    role = relationship("Role", back_populates="users")
    station = relationship("Station", back_populates="users")
    auth_sessions = relationship("AuthSession", back_populates="user")
    attendance_records = relationship(
        "AttendanceRecord",
        back_populates="user",
        foreign_keys="AttendanceRecord.user_id",
    )
