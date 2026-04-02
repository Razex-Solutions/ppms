from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base


class Tanker(Base):
    __tablename__ = "tankers"

    id = Column(Integer, primary_key=True, index=True)
    registration_no = Column(String, unique=True, nullable=False, index=True)
    name = Column(String, nullable=False)
    capacity = Column(Float, nullable=False)

    owner_name = Column(String, nullable=True)
    driver_name = Column(String, nullable=True)
    driver_phone = Column(String, nullable=True)
    status = Column(String, default="active")  # active / inactive / maintenance

    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)
    fuel_type_id = Column(Integer, ForeignKey("fuel_types.id"), nullable=False)

    station = relationship("Station")
    fuel_type = relationship("FuelType")