from sqlalchemy.orm import Session

from app.models.document_template import DocumentTemplate
from app.models.invoice_profile import InvoiceProfile
from app.models.station import Station
from app.services.compliance import get_business_display_name


class _SafeFormatDict(dict):
    def __missing__(self, key):
        return "{" + key + "}"


def get_document_template(db: Session, station: Station, document_type: str) -> DocumentTemplate | None:
    return (
        db.query(DocumentTemplate)
        .filter(
            DocumentTemplate.station_id == station.id,
            DocumentTemplate.document_type == document_type,
            DocumentTemplate.is_active.is_(True),
        )
        .first()
    )


def build_profile_header(profile: InvoiceProfile | None, station: Station) -> str:
    business_name = get_business_display_name(profile, station)
    logo_html = f"<img src='{profile.logo_url}' alt='logo' style='max-height:64px;' />" if profile and profile.logo_url else ""
    taxes = []
    if profile and profile.registration_no:
        taxes.append(f"<div>Registration No: {profile.registration_no}</div>")
    if profile and profile.tax_registration_no:
        taxes.append(f"<div>Tax Registration No: {profile.tax_registration_no}</div>")
    if profile and profile.tax_label_1 and profile.tax_value_1:
        taxes.append(f"<div>{profile.tax_label_1}: {profile.tax_value_1}</div>")
    if profile and profile.tax_label_2 and profile.tax_value_2:
        taxes.append(f"<div>{profile.tax_label_2}: {profile.tax_value_2}</div>")
    contact_lines = []
    if profile and profile.contact_email:
        contact_lines.append(f"<div>Email: {profile.contact_email}</div>")
    if profile and profile.contact_phone:
        contact_lines.append(f"<div>Phone: {profile.contact_phone}</div>")
    return f"""
    <div>
      {logo_html}
      <h2>{business_name}</h2>
      <div>{station.address or ''} {station.city or ''}</div>
      {''.join(contact_lines)}
      {''.join(taxes)}
    </div>
    """


def render_template_fragment(fragment: str | None, context: dict) -> str:
    if not fragment:
        return ""
    return fragment.format_map(_SafeFormatDict(context))


def compose_document_html(
    *,
    template: DocumentTemplate | None,
    default_header_html: str,
    default_body_html: str,
    default_footer_html: str,
    context: dict,
) -> str:
    header_html = render_template_fragment(template.header_html, context) if template and template.header_html else default_header_html
    body_html = render_template_fragment(template.body_html, context) if template and template.body_html else default_body_html
    footer_html = render_template_fragment(template.footer_html, context) if template and template.footer_html else default_footer_html
    return f"<html><body>{header_html}{body_html}{footer_html}</body></html>"
