from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user
from app.models.invoice_profile import InvoiceProfile
from app.models.station import Station
from app.models.user import User
from app.schemas.invoice_profile import InvoiceProfileUpdate
from app.services.compliance import validate_invoice_profile_policy


def ensure_invoice_profile_access(db: Session, station_id: int, current_user: User) -> Station:
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    if current_user.role.name == "Admin":
        return station
    if is_head_office_user(current_user):
        if station.organization_id == get_user_organization_id(current_user):
            return station
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    if current_user.station_id != station_id or current_user.role.name != "Manager":
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    return station


def get_or_create_invoice_profile(db: Session, station: Station) -> InvoiceProfile:
    profile = db.query(InvoiceProfile).filter(InvoiceProfile.station_id == station.id).first()
    if profile is None:
        profile = InvoiceProfile(
            station_id=station.id,
            business_name=station.name,
            invoice_prefix=station.code,
            invoice_number_width=6,
            default_tax_rate=0,
            tax_inclusive=False,
            compliance_mode="standard",
        )
        db.add(profile)
        db.commit()
        db.refresh(profile)
    return profile


def update_invoice_profile(db: Session, station: Station, data: InvoiceProfileUpdate) -> InvoiceProfile:
    profile = get_or_create_invoice_profile(db, station)
    for field, value in data.model_dump().items():
        setattr(profile, field, value)
    validate_invoice_profile_policy(profile)
    db.commit()
    db.refresh(profile)
    return profile
