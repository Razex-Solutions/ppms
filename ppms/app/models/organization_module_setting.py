from sqlalchemy import Boolean, Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.models.base import Base


class OrganizationModuleSetting(Base):
    __tablename__ = "organization_module_settings"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("organizations.id"), nullable=False, index=True)
    module_name = Column(String, nullable=False, index=True)
    is_enabled = Column(Boolean, nullable=False, default=False)

    organization = relationship("Organization")
