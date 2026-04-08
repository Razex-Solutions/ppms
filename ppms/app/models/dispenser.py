from sqlalchemy import Boolean, Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base


class Dispenser(Base):
    __tablename__ = "dispensers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, unique=True, nullable=False, index=True)
    location = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)

    nozzles = relationship("Nozzle", back_populates="dispenser")
