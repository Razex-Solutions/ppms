from sqlalchemy import Boolean, Column, Integer, String

from app.models.base import Base


class BrandCatalog(Base):
    __tablename__ = "brand_catalog"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, nullable=False, index=True)
    name = Column(String, nullable=False, unique=True, index=True)
    logo_url = Column(String, nullable=True)
    primary_color = Column(String, nullable=True)
    sort_order = Column(Integer, nullable=False, default=0)
    is_active = Column(Boolean, nullable=False, default=True)
