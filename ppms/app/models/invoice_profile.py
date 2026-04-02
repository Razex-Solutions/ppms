from sqlalchemy import Column, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.models.base import Base


class InvoiceProfile(Base):
    __tablename__ = "invoice_profiles"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, unique=True, index=True)
    business_name = Column(String, nullable=False)
    logo_url = Column(String, nullable=True)
    tax_label_1 = Column(String, nullable=True)
    tax_value_1 = Column(String, nullable=True)
    tax_label_2 = Column(String, nullable=True)
    tax_value_2 = Column(String, nullable=True)
    contact_email = Column(String, nullable=True)
    contact_phone = Column(String, nullable=True)
    footer_text = Column(Text, nullable=True)
    invoice_prefix = Column(String, nullable=True)

    station = relationship("Station")
