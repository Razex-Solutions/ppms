from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.station import Station
from app.models.user import User
from app.schemas.accounting import ProfitSummaryResponse
from app.services.audit import log_audit_event
from app.services.reports import build_profit_summary

router = APIRouter(prefix="/accounting", tags=["Accounting"])


def _resolve_profit_scope(
    db: Session,
    current_user: User,
    station_id: int | None,
    organization_id: int | None,
) -> tuple[int | None, int | None]:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        if station_id is not None and organization_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Station does not belong to the requested organization")
        return station_id, organization_id

    if is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        if organization_id is None:
            raise HTTPException(status_code=403, detail="Head office user must belong to an organization")
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Station does not belong to your organization")
        return station_id, organization_id

    return current_user.station_id, get_user_organization_id(current_user)


@router.get("/profit-summary", response_model=ProfitSummaryResponse)
def profit_summary(
    station_id: int | None = Query(None),
    organization_id: int | None = Query(None),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view profit summaries")
    station_id, organization_id = _resolve_profit_scope(
        db,
        current_user,
        station_id,
        organization_id,
    )
    summary = build_profit_summary(
        db,
        station_id=station_id,
        organization_id=organization_id,
        from_date=from_date,
        to_date=to_date,
    )
    log_audit_event(
        db,
        current_user=current_user,
        module="accounting",
        action="accounting.profit_summary",
        entity_type="report",
        station_id=station_id,
        details={
            "organization_id": organization_id,
            "from_date": str(from_date) if from_date else None,
            "to_date": str(to_date) if to_date else None,
        },
    )
    db.commit()
    return ProfitSummaryResponse(**summary)
