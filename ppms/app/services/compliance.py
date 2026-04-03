import re
from xml.sax.saxutils import escape

from app.models.invoice_profile import InvoiceProfile
from app.models.station import Station


VALID_COMPLIANCE_MODES = {"standard", "regional_strict", "tax_exempt"}
DEFAULT_REGION_CODE = "DEFAULT"
DEFAULT_CURRENCY_CODE = "PKR"
DOCUMENT_CODE_PATTERN = re.compile(r"[^A-Z0-9]+")

COMPLIANCE_PRESETS = {
    "DEFAULT": {
        "region_code": "DEFAULT",
        "currency_code": "PKR",
        "compliance_mode": "standard",
        "enforce_tax_registration": False,
        "default_tax_rate": 0,
        "tax_inclusive": False,
        "tax_label_1": "Tax",
    },
    "PK-DEFAULT": {
        "region_code": "PK",
        "currency_code": "PKR",
        "compliance_mode": "regional_strict",
        "enforce_tax_registration": True,
        "default_tax_rate": 18,
        "tax_inclusive": False,
        "tax_label_1": "GST",
    },
    "PK-SINDH": {
        "region_code": "PK-SINDH",
        "currency_code": "PKR",
        "compliance_mode": "regional_strict",
        "enforce_tax_registration": True,
        "default_tax_rate": 18,
        "tax_inclusive": False,
        "tax_label_1": "SRB GST",
    },
    "PK-PUNJAB": {
        "region_code": "PK-PUNJAB",
        "currency_code": "PKR",
        "compliance_mode": "regional_strict",
        "enforce_tax_registration": True,
        "default_tax_rate": 18,
        "tax_inclusive": False,
        "tax_label_1": "PRA GST",
    },
    "TAX-EXEMPT": {
        "region_code": "DEFAULT",
        "currency_code": "PKR",
        "compliance_mode": "tax_exempt",
        "enforce_tax_registration": False,
        "default_tax_rate": 0,
        "tax_inclusive": False,
        "tax_label_1": "Tax Exempt",
    },
}


def _normalize_document_segment(value: str | None, fallback: str) -> str:
    cleaned = DOCUMENT_CODE_PATTERN.sub("-", (value or fallback).strip().upper()).strip("-")
    return cleaned or fallback


def list_compliance_presets() -> list[dict]:
    return [
        {"code": code, **values}
        for code, values in COMPLIANCE_PRESETS.items()
    ]


def get_compliance_preset(code: str) -> dict:
    preset = COMPLIANCE_PRESETS.get(code.upper())
    if not preset:
        raise ValueError("Unknown compliance preset")
    return {"code": code.upper(), **preset}


def apply_compliance_preset(profile: InvoiceProfile, preset_code: str) -> InvoiceProfile:
    preset = get_compliance_preset(preset_code)
    profile.region_code = preset["region_code"]
    profile.currency_code = preset["currency_code"]
    profile.compliance_mode = preset["compliance_mode"]
    profile.enforce_tax_registration = preset["enforce_tax_registration"]
    profile.default_tax_rate = preset["default_tax_rate"]
    profile.tax_inclusive = preset["tax_inclusive"]
    if not profile.tax_label_1:
        profile.tax_label_1 = preset["tax_label_1"]
    return profile


def get_business_display_name(profile: InvoiceProfile | None, station: Station) -> str:
    if profile and profile.legal_name:
        return profile.legal_name
    if profile and profile.business_name:
        return profile.business_name
    return station.name


def build_document_number(profile: InvoiceProfile | None, suffix: str) -> str:
    prefix = _normalize_document_segment(profile.invoice_prefix if profile else None, "DOC")
    series = _normalize_document_segment(profile.invoice_series if profile else None, "") if profile and profile.invoice_series else None
    parts = [prefix]
    if series:
        parts.append(series)
    parts.append(_normalize_document_segment(suffix, "DOC"))
    return "-".join(parts)


def build_numbered_suffix(profile: InvoiceProfile | None, code: str, entity_id: int) -> str:
    width = profile.invoice_number_width if profile and profile.invoice_number_width else 6
    return f"{_normalize_document_segment(code, 'DOC')}-{str(entity_id).zfill(width)}"


def calculate_tax_breakdown(profile: InvoiceProfile | None, amount: float) -> tuple[float, float, float]:
    rate = profile.default_tax_rate if profile else 0
    if profile and profile.compliance_mode == "tax_exempt":
        rate = 0
    if not rate:
        return round(amount, 2), 0.0, round(amount, 2)
    if profile and profile.tax_inclusive:
        subtotal = amount / (1 + (rate / 100))
        tax_amount = amount - subtotal
        total = amount
    else:
        subtotal = amount
        tax_amount = amount * (rate / 100)
        total = subtotal + tax_amount
    return round(subtotal, 2), round(tax_amount, 2), round(total, 2)


def get_tax_label(profile: InvoiceProfile | None) -> str:
    if profile and profile.tax_label_1:
        return profile.tax_label_1
    return "Tax"


def validate_invoice_profile_policy(profile: InvoiceProfile) -> None:
    if profile.compliance_mode not in VALID_COMPLIANCE_MODES:
        raise ValueError("Invalid compliance mode")
    if profile.invoice_number_width and profile.invoice_number_width < 3:
        raise ValueError("Invoice number width must be at least 3")
    if profile.invoice_number_width and profile.invoice_number_width > 12:
        raise ValueError("Invoice number width must not exceed 12")
    if profile.default_tax_rate is not None and profile.default_tax_rate < 0:
        raise ValueError("Default tax rate cannot be negative")
    if profile.default_tax_rate is not None and profile.default_tax_rate > 100:
        raise ValueError("Default tax rate cannot exceed 100")
    if profile.invoice_prefix and len(_normalize_document_segment(profile.invoice_prefix, "DOC")) < 2:
        raise ValueError("Invoice prefix must contain at least 2 valid characters")
    if profile.enforce_tax_registration and not profile.tax_registration_no:
        raise ValueError("Tax registration number is required when tax registration enforcement is enabled")
    if profile.compliance_mode == "regional_strict":
        required_fields = {
            "legal_name": profile.legal_name,
            "registration_no": profile.registration_no,
            "region_code": profile.region_code,
            "currency_code": profile.currency_code,
            "invoice_prefix": profile.invoice_prefix,
            "invoice_series": profile.invoice_series,
        }
        missing = [name for name, value in required_fields.items() if not value]
        if missing:
            raise ValueError(f"Regional strict mode requires: {', '.join(missing)}")
        if not profile.tax_label_1:
            raise ValueError("Regional strict mode requires a primary tax label")


def get_document_policy_context(profile: InvoiceProfile | None) -> dict:
    return {
        "currency_code": profile.currency_code if profile and profile.currency_code else DEFAULT_CURRENCY_CODE,
        "region_code": profile.region_code if profile and profile.region_code else DEFAULT_REGION_CODE,
        "compliance_mode": profile.compliance_mode if profile else "standard",
        "enforce_tax_registration": profile.enforce_tax_registration if profile else False,
        "tax_label": get_tax_label(profile),
    }


def build_fuel_sale_einvoice_payload(
    *,
    profile: InvoiceProfile | None,
    station: Station,
    sale,
    subtotal: float,
    tax_amount: float,
    total_amount: float,
    document_number: str,
) -> dict:
    policy = get_document_policy_context(profile)
    customer_name = sale.customer.name if sale.customer else "Walk-in Customer"
    customer_contact = sale.customer.phone if sale.customer else None
    return {
        "schema_version": "ppms.einvoice.v1",
        "document_type": "fuel_sale_invoice",
        "document_number": document_number,
        "issued_at": sale.created_at.isoformat(),
        "seller": {
            "business_name": profile.business_name if profile and profile.business_name else station.name,
            "legal_name": get_business_display_name(profile, station),
            "registration_no": profile.registration_no if profile else None,
            "tax_registration_no": profile.tax_registration_no if profile else None,
            "region_code": policy["region_code"],
            "currency_code": policy["currency_code"],
        },
        "buyer": {
            "name": customer_name,
            "contact": customer_contact,
            "account_type": sale.sale_type,
        },
        "lines": [
            {
                "description": sale.fuel_type.name,
                "quantity": round(sale.quantity, 2),
                "unit": "liter",
                "unit_price": round(sale.rate_per_liter, 2),
                "subtotal": round(subtotal, 2),
            }
        ],
        "tax": {
            "mode": policy["compliance_mode"],
            "label": policy["tax_label"],
            "amount": round(tax_amount, 2),
        },
        "totals": {
            "subtotal": round(subtotal, 2),
            "tax": round(tax_amount, 2),
            "grand_total": round(total_amount, 2),
        },
        "payment_terms": profile.payment_terms if profile and profile.payment_terms else None,
        "notes": profile.sale_invoice_notes if profile and profile.sale_invoice_notes else None,
    }


def build_fuel_sale_einvoice_xml(payload: dict) -> str:
    seller = payload["seller"]
    buyer = payload["buyer"]
    totals = payload["totals"]
    tax = payload["tax"]
    line = payload["lines"][0]
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        f'<PPMSEInvoice schemaVersion="{escape(payload["schema_version"])}">'
        f'<Document type="{escape(payload["document_type"])}" number="{escape(payload["document_number"])}" issuedAt="{escape(payload["issued_at"])}" />'
        f'<Seller businessName="{escape(str(seller["business_name"]))}" legalName="{escape(str(seller["legal_name"]))}" '
        f'registrationNo="{escape(str(seller.get("registration_no") or ""))}" taxRegistrationNo="{escape(str(seller.get("tax_registration_no") or ""))}" '
        f'regionCode="{escape(str(seller["region_code"]))}" currencyCode="{escape(str(seller["currency_code"]))}" />'
        f'<Buyer name="{escape(str(buyer["name"]))}" contact="{escape(str(buyer.get("contact") or ""))}" accountType="{escape(str(buyer["account_type"]))}" />'
        f'<Line description="{escape(str(line["description"]))}" quantity="{line["quantity"]}" unit="{escape(str(line["unit"]))}" '
        f'unitPrice="{line["unit_price"]}" subtotal="{line["subtotal"]}" />'
        f'<Tax mode="{escape(str(tax["mode"]))}" label="{escape(str(tax["label"]))}" amount="{tax["amount"]}" />'
        f'<Totals subtotal="{totals["subtotal"]}" tax="{totals["tax"]}" grandTotal="{totals["grand_total"]}" />'
        f'<Notes>{escape(str(payload.get("notes") or ""))}</Notes>'
        '</PPMSEInvoice>'
    )
