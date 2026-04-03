from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class InboundWebhookEvent(Base):
    __tablename__ = "inbound_webhook_events"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("organizations.id"), nullable=False, index=True)
    hook_name = Column(String, nullable=False, index=True)
    event_type = Column(String, nullable=False, index=True)
    source = Column(String, nullable=False, default="external")
    headers_json = Column(Text, nullable=True)
    payload_json = Column(Text, nullable=True)
    status = Column(String, nullable=False, default="received", index=True)
    detail = Column(Text, nullable=True)
    received_at = Column(DateTime, nullable=False, default=utc_now, index=True)

    organization = relationship("Organization")
