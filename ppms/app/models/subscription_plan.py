from sqlalchemy import Boolean, Column, Float, Integer, String, Text
from sqlalchemy.orm import relationship

from app.models.base import Base


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    code = Column(String, nullable=False, unique=True, index=True)
    description = Column(Text, nullable=True)
    monthly_price = Column(Float, nullable=False, default=0)
    yearly_price = Column(Float, nullable=True)
    max_stations = Column(Integer, nullable=True)
    max_users = Column(Integer, nullable=True)
    feature_summary = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    is_default = Column(Boolean, nullable=False, default=False)

    subscriptions = relationship("OrganizationSubscription", back_populates="plan")
