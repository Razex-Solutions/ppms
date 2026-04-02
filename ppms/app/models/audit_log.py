from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text

from app.core.time import utc_now
from app.models.base import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    username = Column(String, nullable=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=True, index=True)
    module = Column(String, nullable=False, index=True)
    action = Column(String, nullable=False, index=True)
    entity_type = Column(String, nullable=False, index=True)
    entity_id = Column(Integer, nullable=True, index=True)
    details_json = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now, index=True)
