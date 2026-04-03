from sqlalchemy.orm import Session

from app.models.station import Station
from app.schemas.document_template import DocumentTemplateUpsert
from app.services.document_template_catalog import DEFAULT_TEMPLATES
from app.services.document_templates import upsert_document_template


def seed_default_document_templates(db: Session, station: Station) -> list:
    created = []
    for document_type, template_data in DEFAULT_TEMPLATES.items():
        template = upsert_document_template(
            db,
            station=station,
            document_type=document_type,
            data=DocumentTemplateUpsert(
                name=template_data["name"],
                header_html=None,
                body_html=template_data["body_html"],
                footer_html="<div>{footer_text}</div>",
                is_active=True,
            ),
        )
        created.append(template)
    return created
