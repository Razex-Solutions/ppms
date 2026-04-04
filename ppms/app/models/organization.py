from sqlalchemy import Boolean, Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.models.base import Base


class Organization(Base):
    __tablename__ = "organizations"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    code = Column(String, unique=True, nullable=False, index=True)
    description = Column(String, nullable=True)
    legal_name = Column(String, nullable=True)
    brand_catalog_id = Column(Integer, ForeignKey("brand_catalog.id"), nullable=True, index=True)
    brand_name = Column(String, nullable=True, index=True)
    brand_code = Column(String, nullable=True, index=True)
    logo_url = Column(String, nullable=True)
    contact_email = Column(String, nullable=True)
    contact_phone = Column(String, nullable=True)
    registration_number = Column(String, nullable=True)
    tax_registration_number = Column(String, nullable=True)
    onboarding_status = Column(String, nullable=False, default="draft", index=True)
    billing_status = Column(String, nullable=False, default="trial", index=True)
    station_target_count = Column(Integer, nullable=True)
    inherit_branding_to_stations = Column(Boolean, nullable=False, default=True)
    is_active = Column(Boolean, nullable=False, default=True)

    stations = relationship("Station", back_populates="organization")
    brand_catalog = relationship("BrandCatalog")
