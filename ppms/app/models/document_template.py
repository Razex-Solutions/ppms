from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.models.base import Base


class DocumentTemplate(Base):
    __tablename__ = "document_templates"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, index=True)
    document_type = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    header_html = Column(Text, nullable=True)
    body_html = Column(Text, nullable=True)
    footer_html = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    station = relationship("Station")
