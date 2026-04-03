from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String

from app.models.base import Base


class HardwareDevice(Base):
    __tablename__ = "hardware_devices"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, unique=True, nullable=False, index=True)
    device_type = Column(String, nullable=False)
    vendor_name = Column(String, nullable=True)
    integration_mode = Column(String, nullable=False, default="simulated")
    protocol = Column(String, nullable=True)
    endpoint_url = Column(String, nullable=True)
    device_identifier = Column(String, nullable=True)
    api_key = Column(String, nullable=True)
    status = Column(String, nullable=False, default="offline")
    is_active = Column(Boolean, nullable=False, default=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)
    dispenser_id = Column(Integer, ForeignKey("dispensers.id"), nullable=True)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=True)
    last_seen_at = Column(DateTime, nullable=True)
    last_error = Column(String, nullable=True)
