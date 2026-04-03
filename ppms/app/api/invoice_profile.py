from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.user import User
from app.schemas.invoice_profile import InvoiceProfileResponse, InvoiceProfileUpdate
from app.services.compliance import list_compliance_presets
from app.services.invoice_profiles import (
    apply_invoice_profile_preset,
    ensure_invoice_profile_access,
    get_or_create_invoice_profile,
    update_invoice_profile,
)

router = APIRouter(prefix="/invoice-profiles", tags=["Invoice Profiles"])


@router.get("/compliance-presets")
def get_compliance_presets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "invoice_profiles", "read", detail="You do not have permission to view invoice profiles")
    return {"items": list_compliance_presets()}


@router.get("/{station_id}", response_model=InvoiceProfileResponse)
def get_invoice_profile(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "invoice_profiles", "read", detail="You do not have permission to view invoice profiles")
    station = ensure_invoice_profile_access(db, station_id, current_user)
    return get_or_create_invoice_profile(db, station)


@router.put("/{station_id}", response_model=InvoiceProfileResponse)
def put_invoice_profile(
    station_id: int,
    data: InvoiceProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "invoice_profiles", "update", detail="You do not have permission to update invoice profiles")
    station = ensure_invoice_profile_access(db, station_id, current_user)
    return update_invoice_profile(db, station, data)


@router.post("/{station_id}/apply-preset", response_model=InvoiceProfileResponse)
def post_invoice_profile_preset(
    station_id: int,
    preset_code: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "invoice_profiles", "update", detail="You do not have permission to update invoice profiles")
    station = ensure_invoice_profile_access(db, station_id, current_user)
    return apply_invoice_profile_preset(db, station, preset_code)
