import io
import re

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

from app.schemas.financial_document import FinancialDocumentResponse


def _html_to_text_lines(rendered_html: str) -> list[str]:
    normalized = re.sub(r"<\s*/?(br|div|p|h1|h2|h3|tr|td|th|table)[^>]*>", "\n", rendered_html, flags=re.IGNORECASE)
    stripped = re.sub(r"<[^>]+>", "", normalized)
    lines = [line.strip() for line in stripped.splitlines()]
    return [line for line in lines if line]


def render_financial_document_pdf(document: FinancialDocumentResponse) -> bytes:
    buffer = io.BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4
    y = height - 50

    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(40, y, document.title)
    y -= 24

    pdf.setFont("Helvetica", 10)
    header_lines = [
        f"Document No: {document.document_number}",
        f"Generated At: {document.generated_at.isoformat()}",
        f"Recipient: {document.recipient_name}",
    ]
    if document.recipient_contact:
        header_lines.append(f"Contact: {document.recipient_contact}")
    if document.total_amount is not None:
        header_lines.append(f"Total Amount: {document.total_amount:.2f}")
    if document.balance is not None:
        header_lines.append(f"Balance: {document.balance:.2f}")

    for line in header_lines:
        pdf.drawString(40, y, line)
        y -= 14

    y -= 10
    pdf.setFont("Helvetica", 9)
    for line in _html_to_text_lines(document.rendered_html):
        if y < 50:
            pdf.showPage()
            pdf.setFont("Helvetica", 9)
            y = height - 50
        pdf.drawString(40, y, line[:110])
        y -= 12

    pdf.showPage()
    pdf.save()
    return buffer.getvalue()
