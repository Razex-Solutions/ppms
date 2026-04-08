from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.models.base import Base


class TankerTripDriverAssignment(Base):
    __tablename__ = "tanker_trip_driver_assignments"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("tanker_trips.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    assignment_role = Column(String, nullable=False, default="driver")

    trip = relationship("TankerTrip", back_populates="driver_assignments")
    user = relationship("User")
