from pydantic import BaseModel, ConfigDict


class InvoiceProfileUpdate(BaseModel):
    business_name: str
    logo_url: str | None = None
    tax_label_1: str | None = None
    tax_value_1: str | None = None
    tax_label_2: str | None = None
    tax_value_2: str | None = None
    contact_email: str | None = None
    contact_phone: str | None = None
    footer_text: str | None = None
    invoice_prefix: str | None = None


class InvoiceProfileResponse(BaseModel):
    id: int
    station_id: int
    business_name: str
    logo_url: str | None = None
    tax_label_1: str | None = None
    tax_value_1: str | None = None
    tax_label_2: str | None = None
    tax_value_2: str | None = None
    contact_email: str | None = None
    contact_phone: str | None = None
    footer_text: str | None = None
    invoice_prefix: str | None = None

    model_config = ConfigDict(from_attributes=True)
