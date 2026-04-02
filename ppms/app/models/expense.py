from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime
from app.models.base import Base
from app.core.time import utc_now


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    category = Column(String, nullable=False)
    amount = Column(Float, nullable=False)
    notes = Column(String, nullable=True)

    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False)

    created_at = Column(DateTime, default=utc_now)
