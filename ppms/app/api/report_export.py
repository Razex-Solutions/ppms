from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session

from app.core.access import is_master_admin
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.report_export_job import ReportExportJob
from app.models.user import User
from app.schemas.report_export import ReportExportCreate, ReportExportResponse
from app.services.audit import log_audit_event
from app.services.report_exports import create_report_export_job, ensure_export_access

router = APIRouter(prefix="/report-exports", tags=["Report Exports"])


@router.post("/", response_model=ReportExportResponse)
def create_export(
    data: ReportExportCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to export reports")
    return create_report_export_job(
        db,
        current_user=current_user,
        report_type=data.report_type,
        export_format=data.format,
        station_id=data.station_id,
        organization_id=data.organization_id,
        report_date=data.report_date,
        from_date=data.from_date,
        to_date=data.to_date,
    )


@router.get("/", response_model=list[ReportExportResponse])
def list_exports(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    report_type: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view report exports")
    query = db.query(ReportExportJob)
    if is_master_admin(current_user):
        pass
    elif current_user.role.name == "HeadOffice":
        organization_id = current_user.station.organization_id if current_user.station else None
        query = query.filter(ReportExportJob.organization_id == organization_id)
    else:
        query = query.filter(ReportExportJob.station_id == current_user.station_id)
    if report_type:
        query = query.filter(ReportExportJob.report_type == report_type)
    return query.order_by(ReportExportJob.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{job_id}", response_model=ReportExportResponse)
def get_export(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view report exports")
    job = db.query(ReportExportJob).filter(ReportExportJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Report export job not found")
    ensure_export_access(job, current_user)
    return job


@router.get("/{job_id}/download")
def download_export(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to download report exports")
    job = db.query(ReportExportJob).filter(ReportExportJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Report export job not found")
    ensure_export_access(job, current_user)
    log_audit_event(
        db,
        current_user=current_user,
        module="report_exports",
        action="report_exports.download",
        entity_type="report_export_job",
        entity_id=job.id,
        station_id=job.station_id,
        details={"report_type": job.report_type, "file_name": job.file_name},
    )
    db.commit()
    headers = {"Content-Disposition": f'attachment; filename="{job.file_name}"'}
    return Response(content=job.content_text, media_type=job.content_type, headers=headers)
