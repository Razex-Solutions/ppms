import smtplib
from email.message import EmailMessage

import requests

from app.core.config import (
    APP_ENV,
    DELIVERY_MODE,
    SMTP_FROM_EMAIL,
    SMTP_HOST,
    SMTP_PASSWORD,
    SMTP_PORT,
    SMTP_USERNAME,
    SMTP_USE_TLS,
    TWILIO_ACCOUNT_SID,
    TWILIO_AUTH_TOKEN,
    TWILIO_SMS_FROM,
    TWILIO_WHATSAPP_FROM,
)


def _mock_enabled() -> bool:
    return DELIVERY_MODE == "mock" or APP_ENV in {"development", "test"}


def deliver_email(
    *,
    to_email: str | None,
    subject: str,
    body_text: str,
    body_html: str | None = None,
    attachment_bytes: bytes | None = None,
    attachment_filename: str | None = None,
    attachment_content_type: str = "application/octet-stream",
) -> tuple[str, str | None]:
    if not to_email:
        return "skipped", "No destination configured for email"
    if _mock_enabled():
        return "sent", f"Mock email delivery to {to_email}"
    if not (SMTP_HOST and SMTP_FROM_EMAIL):
        return "skipped", "SMTP provider is not configured"

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = SMTP_FROM_EMAIL
    message["To"] = to_email
    message.set_content(body_text)
    if body_html:
        message.add_alternative(body_html, subtype="html")
    if attachment_bytes is not None and attachment_filename:
        maintype, subtype = attachment_content_type.split("/", 1)
        message.add_attachment(
            attachment_bytes,
            maintype=maintype,
            subtype=subtype,
            filename=attachment_filename,
        )

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=20) as server:
            if SMTP_USE_TLS:
                server.starttls()
            if SMTP_USERNAME:
                server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(message)
        return "sent", None
    except Exception as exc:
        return "failed", f"SMTP delivery failed: {exc}"


def deliver_sms(*, to_number: str | None, body_text: str) -> tuple[str, str | None]:
    if not to_number:
        return "skipped", "No destination configured for sms"
    if _mock_enabled():
        return "sent", f"Mock sms delivery to {to_number}"
    if not (TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN and TWILIO_SMS_FROM):
        return "skipped", "Twilio SMS provider is not configured"

    url = f"https://api.twilio.com/2010-04-01/Accounts/{TWILIO_ACCOUNT_SID}/Messages.json"
    try:
        response = requests.post(
            url,
            auth=(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN),
            data={"From": TWILIO_SMS_FROM, "To": to_number, "Body": body_text},
            timeout=20,
        )
        if response.ok:
            return "sent", None
        return "failed", f"Twilio SMS failed: {response.status_code}"
    except Exception as exc:
        return "failed", f"Twilio SMS failed: {exc}"


def deliver_whatsapp(*, to_number: str | None, body_text: str) -> tuple[str, str | None]:
    if not to_number:
        return "skipped", "No destination configured for whatsapp"
    if _mock_enabled():
        return "sent", f"Mock whatsapp delivery to {to_number}"
    if not (TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN and TWILIO_WHATSAPP_FROM):
        return "skipped", "Twilio WhatsApp provider is not configured"

    url = f"https://api.twilio.com/2010-04-01/Accounts/{TWILIO_ACCOUNT_SID}/Messages.json"
    try:
        formatted_to = to_number if to_number.startswith("whatsapp:") else f"whatsapp:{to_number}"
        formatted_from = (
            TWILIO_WHATSAPP_FROM
            if TWILIO_WHATSAPP_FROM.startswith("whatsapp:")
            else f"whatsapp:{TWILIO_WHATSAPP_FROM}"
        )
        response = requests.post(
            url,
            auth=(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN),
            data={"From": formatted_from, "To": formatted_to, "Body": body_text},
            timeout=20,
        )
        if response.ok:
            return "sent", None
        return "failed", f"Twilio WhatsApp failed: {response.status_code}"
    except Exception as exc:
        return "failed", f"Twilio WhatsApp failed: {exc}"
