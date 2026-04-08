import json

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.report_definition import ReportDefinition
from app.models.station import Station
from app.models.user import User
from app.schemas.report_definition import (
    ReportDefinitionCreate,
    ReportDefinitionResponse,
    ReportDefinitionUpdate,
)

router = APIRouter(prefix="/report-definitions", tags=["Report Definitions"])


def _serialize(definition: ReportDefinition) -> ReportDefinitionResponse:
    return ReportDefinitionResponse(
        id=definition.id,
        name=definition.name,
        report_type=definition.report_type,
        station_id=definition.station_id,
        organization_id=definition.organization_id,
        created_by_user_id=definition.created_by_user_id,
        is_shared=definition.is_shared,
        filters=json.loads(definition.filters_json) if definition.filters_json else {},
        created_at=definition.created_at,
        updated_at=definition.updated_at,
    )


def _apply_scope(query, current_user: User):
    if is_master_admin(current_user):
        return query
    if current_user.role.name == "HeadOffice":
        organization_id = current_user.station.organization_id if current_user.station else None
        return query.filter(
            (ReportDefinition.organization_id == organization_id)
            | (ReportDefinition.station_id == current_user.station_id)
        )
    return query.filter(ReportDefinition.station_id == current_user.station_id)


def _ensure_definition_access(definition: ReportDefinition, current_user: User) -> None:
    if is_master_admin(current_user):
        return
    if current_user.role.name == "HeadOffice":
        organization_id = current_user.station.organization_id if current_user.station else None
        if definition.organization_id == organization_id or definition.station_id == current_user.station_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this report definition")
    if definition.station_id != current_user.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this report definition")


@router.get("/", response_model=list[ReportDefinitionResponse])
def list_report_definitions(
    report_type: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view report definitions")
    query = _apply_scope(db.query(ReportDefinition), current_user)
    if report_type:
        query = query.filter(ReportDefinition.report_type == report_type)
    return [_serialize(item) for item in query.order_by(ReportDefinition.updated_at.desc(), ReportDefinition.id.desc()).all()]


@router.post("/", response_model=ReportDefinitionResponse)
def create_report_definition(
    data: ReportDefinitionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to save report definitions")
    if current_user.role.name != "HeadOffice" and not is_master_admin(current_user):
        data.organization_id = None
        data.station_id = current_user.station_id
    if data.station_id is not None:
        station = db.query(Station).filter(Station.id == data.station_id).first()
        if not station:
            raise HTTPException(status_code=404, detail="Station not found")
        if not is_master_admin(current_user):
            if current_user.role.name == "HeadOffice":
                if station.organization_id != current_user.station.organization_id:
                    raise HTTPException(status_code=403, detail="Not authorized for this station")
            elif station.id != current_user.station_id:
                raise HTTPException(status_code=403, detail="Not authorized for this station")
        if data.organization_id is None:
            data.organization_id = station.organization_id
    definition = ReportDefinition(
        name=data.name.strip(),
        report_type=data.report_type,
        station_id=data.station_id,
        organization_id=data.organization_id,
        created_by_user_id=current_user.id,
        is_shared=data.is_shared,
        filters_json=json.dumps(data.filters),
    )
    db.add(definition)
    db.commit()
    db.refresh(definition)
    return _serialize(definition)


@router.put("/{definition_id}", response_model=ReportDefinitionResponse)
def update_report_definition(
    definition_id: int,
    data: ReportDefinitionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to update report definitions")
    definition = db.query(ReportDefinition).filter(ReportDefinition.id == definition_id).first()
    if not definition:
        raise HTTPException(status_code=404, detail="Report definition not found")
    _ensure_definition_access(definition, current_user)
    updates = data.model_dump(exclude_unset=True)
    if "name" in updates:
        definition.name = updates["name"].strip()
    if "is_shared" in updates:
        definition.is_shared = updates["is_shared"]
    if "filters" in updates:
        definition.filters_json = json.dumps(updates["filters"] or {})
    db.commit()
    db.refresh(definition)
    return _serialize(definition)


@router.delete("/{definition_id}")
def delete_report_definition(
    definition_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to delete report definitions")
    definition = db.query(ReportDefinition).filter(ReportDefinition.id == definition_id).first()
    if not definition:
        raise HTTPException(status_code=404, detail="Report definition not found")
    _ensure_definition_access(definition, current_user)
    db.delete(definition)
    db.commit()
    return {"message": "Report definition deleted"}
