from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text

from app.core.time import utc_now
from app.models.base import Base


class HardwareEvent(Base):
    __tablename__ = "hardware_events"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(Integer, ForeignKey("hardware_devices.id"), nullable=False, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    event_type = Column(String, nullable=False, index=True)
    source = Column(String, nullable=False, default="simulation")
    status = Column(String, nullable=False, default="received")
    dispenser_id = Column(Integer, ForeignKey("dispensers.id"), nullable=True)
    tank_id = Column(Integer, ForeignKey("tanks.id"), nullable=True)
    nozzle_id = Column(Integer, ForeignKey("nozzles.id"), nullable=True)
    meter_reading = Column(Float, nullable=True)
    volume = Column(Float, nullable=True)
    temperature = Column(Float, nullable=True)
    notes = Column(String, nullable=True)
    payload_json = Column(Text, nullable=True)
    recorded_at = Column(DateTime, nullable=False, default=utc_now, index=True)
