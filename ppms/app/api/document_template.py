from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.user import User
from app.schemas.document_template import (
    DocumentTemplatePreviewRequest,
    DocumentTemplatePreviewResponse,
    DocumentTemplateResponse,
    DocumentTemplateUpsert,
)
from app.services.document_templates import (
    ensure_document_template_access,
    get_document_template,
    get_placeholder_catalog,
    list_document_templates,
    preview_document_template,
    upsert_document_template,
)
from app.services.document_template_seed import seed_default_document_templates


router = APIRouter(prefix="/document-templates", tags=["Document Templates"])


@router.get("/{station_id}", response_model=list[DocumentTemplateResponse])
def get_station_document_templates(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "document_templates", "read", detail="You do not have permission to view document templates")
    station = ensure_document_template_access(db, station_id, current_user)
    return list_document_templates(db, station)


@router.get("/{station_id}/{document_type}", response_model=DocumentTemplateResponse | None)
def get_station_document_template(
    station_id: int,
    document_type: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "document_templates", "read", detail="You do not have permission to view document templates")
    station = ensure_document_template_access(db, station_id, current_user)
    return get_document_template(db, station, document_type)


@router.put("/{station_id}/{document_type}", response_model=DocumentTemplateResponse)
def put_station_document_template(
    station_id: int,
    document_type: str,
    data: DocumentTemplateUpsert,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "document_templates", "update", detail="You do not have permission to update document templates")
    station = ensure_document_template_access(db, station_id, current_user)
    return upsert_document_template(db, station=station, document_type=document_type, data=data)


@router.post("/{station_id}/seed-defaults", response_model=list[DocumentTemplateResponse])
def seed_station_document_templates(
    station_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "document_templates", "update", detail="You do not have permission to seed document templates")
    station = ensure_document_template_access(db, station_id, current_user)
    return seed_default_document_templates(db, station)


@router.get("/placeholders/{document_type}")
def get_document_template_placeholders(
    document_type: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "document_templates", "read", detail="You do not have permission to view document template placeholders")
    return {"document_type": document_type, "placeholders": get_placeholder_catalog(document_type)}


@router.post("/preview/{document_type}", response_model=DocumentTemplatePreviewResponse)
def preview_station_document_template(
    document_type: str,
    data: DocumentTemplatePreviewRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "document_templates", "read", detail="You do not have permission to preview document templates")
    return preview_document_template(document_type, data)
