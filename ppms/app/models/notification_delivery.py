from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class NotificationDelivery(Base):
    __tablename__ = "notification_deliveries"

    id = Column(Integer, primary_key=True, index=True)
    notification_id = Column(Integer, ForeignKey("notifications.id"), nullable=False, index=True)
    channel = Column(String, nullable=False, index=True)
    destination = Column(String, nullable=True)
    status = Column(String, nullable=False, default="queued", index=True)
    detail = Column(String, nullable=True)
    attempts_count = Column(Integer, nullable=False, default=0)
    last_attempt_at = Column(DateTime, nullable=True)
    next_retry_at = Column(DateTime, nullable=True, index=True)
    processed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now, index=True)

    notification = relationship("Notification")
