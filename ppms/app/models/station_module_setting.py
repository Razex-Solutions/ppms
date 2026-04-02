from sqlalchemy import Boolean, Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.models.base import Base


class StationModuleSetting(Base):
    __tablename__ = "station_module_settings"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    module_name = Column(String, nullable=False, index=True)
    is_enabled = Column(Boolean, nullable=False, default=False)

    station = relationship("Station")
