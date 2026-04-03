from app.models.invoice_profile import InvoiceProfile
from app.models.station import Station


VALID_COMPLIANCE_MODES = {"standard", "regional_strict", "tax_exempt"}


def get_business_display_name(profile: InvoiceProfile | None, station: Station) -> str:
    if profile and profile.legal_name:
        return profile.legal_name
    if profile and profile.business_name:
        return profile.business_name
    return station.name


def build_document_number(profile: InvoiceProfile | None, suffix: str) -> str:
    prefix = profile.invoice_prefix if profile and profile.invoice_prefix else "DOC"
    series = profile.invoice_series if profile and profile.invoice_series else None
    parts = [prefix]
    if series:
        parts.append(series)
    parts.append(suffix)
    return "-".join(parts)


def build_numbered_suffix(profile: InvoiceProfile | None, code: str, entity_id: int) -> str:
    width = profile.invoice_number_width if profile and profile.invoice_number_width else 6
    return f"{code}-{str(entity_id).zfill(width)}"


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
    if profile.default_tax_rate is not None and profile.default_tax_rate < 0:
        raise ValueError("Default tax rate cannot be negative")
    if profile.enforce_tax_registration and not profile.tax_registration_no:
        raise ValueError("Tax registration number is required when tax registration enforcement is enabled")


def get_document_policy_context(profile: InvoiceProfile | None) -> dict:
    return {
        "currency_code": profile.currency_code if profile and profile.currency_code else "PKR",
        "region_code": profile.region_code if profile and profile.region_code else "DEFAULT",
        "compliance_mode": profile.compliance_mode if profile else "standard",
    }
