from sqlalchemy import Boolean, Column, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.models.base import Base


class TankerCompartment(Base):
    __tablename__ = "tanker_compartments"

    id = Column(Integer, primary_key=True, index=True)
    tanker_id = Column(Integer, ForeignKey("tankers.id"), nullable=False, index=True)
    code = Column(String, nullable=False)
    name = Column(String, nullable=False)
    capacity = Column(Float, nullable=False)
    position = Column(Integer, nullable=False, default=1)
    is_active = Column(Boolean, nullable=False, default=True)

    tanker = relationship("Tanker", back_populates="compartments")
