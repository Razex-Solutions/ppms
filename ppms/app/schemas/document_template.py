from pydantic import BaseModel, ConfigDict


class DocumentTemplateUpsert(BaseModel):
    name: str
    header_html: str | None = None
    body_html: str | None = None
    footer_html: str | None = None
    is_active: bool = True


class DocumentTemplatePreviewRequest(BaseModel):
    header_html: str | None = None
    body_html: str | None = None
    footer_html: str | None = None


class DocumentTemplatePreviewResponse(BaseModel):
    rendered_html: str
    placeholders: list[str]


class DocumentTemplateResponse(BaseModel):
    id: int
    station_id: int
    document_type: str
    name: str
    header_html: str | None = None
    body_html: str | None = None
    footer_html: str | None = None
    is_active: bool

    model_config = ConfigDict(from_attributes=True)
