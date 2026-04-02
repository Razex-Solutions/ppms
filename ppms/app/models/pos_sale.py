from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String

from app.core.time import utc_now
from app.models.base import Base


class POSSale(Base):
    __tablename__ = "pos_sales"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)
    module = Column(String, nullable=False)  # mart / service_station / tyre_shop / other
    payment_method = Column(String, default="cash")
    customer_name = Column(String, nullable=True)
    notes = Column(String, nullable=True)
    total_amount = Column(Float, nullable=False)
    is_reversed = Column(Boolean, default=False, nullable=False)
    reversed_at = Column(DateTime, nullable=True)
    reversed_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=utc_now)
