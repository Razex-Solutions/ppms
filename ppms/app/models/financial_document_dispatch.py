from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class FinancialDocumentDispatch(Base):
    __tablename__ = "financial_document_dispatches"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    requested_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    document_type = Column(String, nullable=False, index=True)
    entity_type = Column(String, nullable=False, index=True)
    entity_id = Column(Integer, nullable=False, index=True)
    channel = Column(String, nullable=False, index=True)
    output_format = Column(String, nullable=False, default="pdf")
    recipient_name = Column(String, nullable=True)
    recipient_contact = Column(String, nullable=True)
    status = Column(String, nullable=False, default="queued", index=True)
    detail = Column(String, nullable=True)
    attempts_count = Column(Integer, nullable=False, default=0)
    last_attempt_at = Column(DateTime, nullable=True)
    next_retry_at = Column(DateTime, nullable=True, index=True)
    processed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=utc_now, index=True)

    station = relationship("Station")
    requested_by = relationship("User")
