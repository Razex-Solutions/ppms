from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text

from app.core.time import utc_now
from app.models.base import Base


class ReportDefinition(Base):
    __tablename__ = "report_definitions"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    report_type = Column(String, nullable=False, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=True, index=True)
    organization_id = Column(Integer, ForeignKey("organizations.id"), nullable=True, index=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    is_shared = Column(Boolean, nullable=False, default=False)
    filters_json = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime, nullable=False, default=utc_now, onupdate=utc_now)
