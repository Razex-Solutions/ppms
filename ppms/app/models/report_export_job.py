from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text

from app.core.time import utc_now
from app.models.base import Base


class ReportExportJob(Base):
    __tablename__ = "report_export_jobs"

    id = Column(Integer, primary_key=True, index=True)
    report_type = Column(String, nullable=False, index=True)
    format = Column(String, nullable=False, default="csv")
    status = Column(String, nullable=False, default="completed", index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=True, index=True)
    organization_id = Column(Integer, ForeignKey("organizations.id"), nullable=True, index=True)
    requested_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    filters_json = Column(Text, nullable=True)
    file_name = Column(String, nullable=False)
    content_type = Column(String, nullable=False, default="text/csv")
    content_text = Column(Text, nullable=False)
    created_at = Column(DateTime, nullable=False, default=utc_now, index=True)
