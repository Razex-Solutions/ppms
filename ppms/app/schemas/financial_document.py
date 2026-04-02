from datetime import datetime

from pydantic import BaseModel, ConfigDict


class FinancialDocumentResponse(BaseModel):
    document_type: str
    station_id: int
    title: str
    document_number: str
    recipient_name: str
    recipient_contact: str | None = None
    total_amount: float | None = None
    balance: float | None = None
    generated_at: datetime
    rendered_html: str


class FinancialDocumentDispatchCreate(BaseModel):
    channel: str
    format: str = "pdf"
    recipient_name: str | None = None
    recipient_contact: str | None = None


class FinancialDocumentDispatchResponse(BaseModel):
    id: int
    station_id: int
    requested_by_user_id: int
    document_type: str
    entity_type: str
    entity_id: int
    channel: str
    output_format: str
    recipient_name: str | None = None
    recipient_contact: str | None = None
    status: str
    detail: str | None = None
    attempts_count: int
    last_attempt_at: datetime | None = None
    next_retry_at: datetime | None = None
    processed_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
