from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.time import utc_now
from app.models.base import Base


class Station(Base):
    __tablename__ = "stations"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    code = Column(String, unique=True, nullable=False, index=True)
    address = Column(String, nullable=True)
    city = Column(String, nullable=True)
    organization_id = Column(Integer, ForeignKey("organizations.id"), nullable=True, index=True)
    is_head_office = Column(Boolean, nullable=False, default=False)
    display_name = Column(String, nullable=True)
    legal_name_override = Column(String, nullable=True)
    brand_name = Column(String, nullable=True)
    brand_code = Column(String, nullable=True)
    logo_url = Column(String, nullable=True)
    use_organization_branding = Column(Boolean, nullable=False, default=True)
    is_active = Column(Boolean, nullable=False, default=True)
    setup_status = Column(String, nullable=False, default="draft", index=True)
    setup_completed_at = Column(DateTime, nullable=True, default=None)
    has_shops = Column(Boolean, nullable=False, default=False)
    has_pos = Column(Boolean, nullable=False, default=False)
    has_tankers = Column(Boolean, nullable=False, default=False)
    has_hardware = Column(Boolean, nullable=False, default=False)
    allow_meter_adjustments = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=utc_now)

    users = relationship("User", back_populates="station")
    organization = relationship("Organization", back_populates="stations")
