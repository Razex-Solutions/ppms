from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class OnlineAPIHook(Base):
    __tablename__ = "online_api_hooks"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("organizations.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    event_type = Column(String, nullable=False, index=True)
    target_url = Column(String, nullable=False)
    auth_type = Column(String, nullable=False, default="none")
    auth_token = Column(Text, nullable=True)
    secret_key = Column(Text, nullable=True)
    signature_header = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=False, default=False)
    last_status = Column(String, nullable=True)
    last_detail = Column(Text, nullable=True)
    last_triggered_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)
    updated_at = Column(DateTime, nullable=False, default=utc_now, onupdate=utc_now)

    organization = relationship("Organization")
