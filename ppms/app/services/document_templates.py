from sqlalchemy.orm import Session

from app.models.document_template import DocumentTemplate
from app.models.station import Station
from app.schemas.document_template import DocumentTemplatePreviewRequest, DocumentTemplateUpsert
from app.services.document_rendering import compose_document_html, render_template_fragment
from app.services.document_template_catalog import PLACEHOLDER_CATALOG
from app.services.invoice_profiles import ensure_invoice_profile_access


def ensure_document_template_access(db: Session, station_id: int, current_user):
    return ensure_invoice_profile_access(db, station_id, current_user)


def list_document_templates(db: Session, station: Station) -> list[DocumentTemplate]:
    return (
        db.query(DocumentTemplate)
        .filter(DocumentTemplate.station_id == station.id)
        .order_by(DocumentTemplate.document_type.asc(), DocumentTemplate.id.asc())
        .all()
    )


def get_document_template(db: Session, station: Station, document_type: str) -> DocumentTemplate | None:
    return (
        db.query(DocumentTemplate)
        .filter(
            DocumentTemplate.station_id == station.id,
            DocumentTemplate.document_type == document_type,
        )
        .first()
    )


def upsert_document_template(
    db: Session,
    *,
    station: Station,
    document_type: str,
    data: DocumentTemplateUpsert,
) -> DocumentTemplate:
    template = get_document_template(db, station, document_type)
    if template is None:
        template = DocumentTemplate(
            station_id=station.id,
            document_type=document_type,
        )
        db.add(template)
    for field, value in data.model_dump().items():
        setattr(template, field, value)
    db.commit()
    db.refresh(template)
    return template


def get_placeholder_catalog(document_type: str) -> list[str]:
    return PLACEHOLDER_CATALOG.get(document_type, [])


def preview_document_template(document_type: str, data: DocumentTemplatePreviewRequest) -> dict:
    placeholders = get_placeholder_catalog(document_type)
    context = {placeholder: f"<{placeholder}>" for placeholder in placeholders}
    rendered_html = compose_document_html(
        template=None,
        default_header_html=render_template_fragment(data.header_html, context),
        default_body_html=render_template_fragment(data.body_html, context),
        default_footer_html=render_template_fragment(data.footer_html, context),
        context=context,
    )
    return {"rendered_html": rendered_html, "placeholders": placeholders}
