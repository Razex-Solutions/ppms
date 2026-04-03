from pydantic import BaseModel, ConfigDict


class InvoiceProfileUpdate(BaseModel):
    business_name: str
    legal_name: str | None = None
    logo_url: str | None = None
    registration_no: str | None = None
    tax_registration_no: str | None = None
    tax_label_1: str | None = None
    tax_value_1: str | None = None
    tax_label_2: str | None = None
    tax_value_2: str | None = None
    default_tax_rate: float = 0
    tax_inclusive: bool = False
    region_code: str | None = None
    currency_code: str | None = None
    compliance_mode: str = "standard"
    enforce_tax_registration: bool = False
    contact_email: str | None = None
    contact_phone: str | None = None
    footer_text: str | None = None
    invoice_prefix: str | None = None
    invoice_series: str | None = None
    invoice_number_width: int = 6
    payment_terms: str | None = None
    sale_invoice_notes: str | None = None


class InvoiceProfileResponse(BaseModel):
    id: int
    station_id: int
    business_name: str
    legal_name: str | None = None
    logo_url: str | None = None
    registration_no: str | None = None
    tax_registration_no: str | None = None
    tax_label_1: str | None = None
    tax_value_1: str | None = None
    tax_label_2: str | None = None
    tax_value_2: str | None = None
    default_tax_rate: float
    tax_inclusive: bool
    region_code: str | None = None
    currency_code: str | None = None
    compliance_mode: str
    enforce_tax_registration: bool
    contact_email: str | None = None
    contact_phone: str | None = None
    footer_text: str | None = None
    invoice_prefix: str | None = None
    invoice_series: str | None = None
    invoice_number_width: int
    payment_terms: str | None = None
    sale_invoice_notes: str | None = None

    model_config = ConfigDict(from_attributes=True)
