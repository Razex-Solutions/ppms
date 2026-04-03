from sqlalchemy import Boolean, Column, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.models.base import Base


class InvoiceProfile(Base):
    __tablename__ = "invoice_profiles"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("stations.id"), nullable=False, unique=True, index=True)
    business_name = Column(String, nullable=False)
    legal_name = Column(String, nullable=True)
    logo_url = Column(String, nullable=True)
    registration_no = Column(String, nullable=True)
    tax_registration_no = Column(String, nullable=True)
    tax_label_1 = Column(String, nullable=True)
    tax_value_1 = Column(String, nullable=True)
    tax_label_2 = Column(String, nullable=True)
    tax_value_2 = Column(String, nullable=True)
    default_tax_rate = Column(Float, nullable=False, default=0)
    tax_inclusive = Column(Boolean, nullable=False, default=False)
    region_code = Column(String, nullable=True)
    currency_code = Column(String, nullable=True)
    compliance_mode = Column(String, nullable=False, default="standard")
    enforce_tax_registration = Column(Boolean, nullable=False, default=False)
    contact_email = Column(String, nullable=True)
    contact_phone = Column(String, nullable=True)
    footer_text = Column(Text, nullable=True)
    invoice_prefix = Column(String, nullable=True)
    invoice_series = Column(String, nullable=True)
    invoice_number_width = Column(Integer, nullable=False, default=6)
    payment_terms = Column(Text, nullable=True)
    sale_invoice_notes = Column(Text, nullable=True)

    station = relationship("Station")
