import csv
import io
import json
from datetime import date

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.report_export_job import ReportExportJob
from app.models.station import Station
from app.models.user import User
from app.services.audit import log_audit_event
from app.services.reports import (
    build_customer_balance_report,
    build_daily_closing_report,
    build_shift_variance_report,
    build_stock_movement_report,
    build_supplier_balance_report,
)


SUPPORTED_REPORTS = {
    "daily_closing",
    "shift_variance",
    "stock_movement",
    "customer_balances",
    "supplier_balances",
}


def resolve_report_scope(
    db: Session,
    current_user: User,
    station_id: int | None,
    organization_id: int | None,
) -> tuple[int | None, int | None]:
    role_name = current_user.role.name
    if role_name == "Admin":
        if station_id is not None and organization_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Station does not belong to the requested organization")
        return station_id, organization_id

    user_organization_id = current_user.station.organization_id if current_user.station else None
    if role_name == "HeadOffice":
        if user_organization_id is None:
            raise HTTPException(status_code=403, detail="Head office user must belong to an organization")
        organization_id = user_organization_id
        if station_id is not None:
            station = db.query(Station).filter(Station.id == station_id).first()
            if not station or station.organization_id != organization_id:
                raise HTTPException(status_code=403, detail="Station does not belong to your organization")
        return station_id, organization_id

    return current_user.station_id, user_organization_id


def _build_report_data(
    db: Session,
    report_type: str,
    station_id: int | None,
    organization_id: int | None,
    report_date: date | None,
    from_date: date | None,
    to_date: date | None,
) -> dict:
    if report_type == "daily_closing":
        if report_date is None:
            raise HTTPException(status_code=400, detail="report_date is required for daily_closing exports")
        return build_daily_closing_report(db, station_id, report_date, organization_id)
    if report_type == "shift_variance":
        return build_shift_variance_report(db, station_id, from_date, to_date, organization_id)
    if report_type == "stock_movement":
        return build_stock_movement_report(db, station_id, from_date, to_date, organization_id)
    if report_type == "customer_balances":
        return build_customer_balance_report(db, station_id, organization_id)
    if report_type == "supplier_balances":
        return build_supplier_balance_report(db, station_id, organization_id)
    raise HTTPException(status_code=400, detail="Unsupported report type")


def _render_csv(report_type: str, data: dict) -> str:
    output = io.StringIO()
    writer = csv.writer(output)

    if report_type == "daily_closing":
        writer.writerow(["field", "value"])
        for key, value in data.items():
            writer.writerow([key, value])
        return output.getvalue()

    items = data.get("items", [])
    if not items:
        writer.writerow(["message"])
        writer.writerow(["No rows"])
        return output.getvalue()

    headers = list(items[0].keys())
    writer.writerow(headers)
    for item in items:
        writer.writerow([item.get(header) for header in headers])
    return output.getvalue()


def create_report_export_job(
    db: Session,
    *,
    current_user: User,
    report_type: str,
    export_format: str,
    station_id: int | None,
    organization_id: int | None,
    report_date: date | None,
    from_date: date | None,
    to_date: date | None,
) -> ReportExportJob:
    if report_type not in SUPPORTED_REPORTS:
        raise HTTPException(status_code=400, detail="Unsupported report type")
    if export_format.lower() != "csv":
        raise HTTPException(status_code=400, detail="Only csv exports are supported right now")

    station_id, organization_id = resolve_report_scope(db, current_user, station_id, organization_id)
    report_data = _build_report_data(db, report_type, station_id, organization_id, report_date, from_date, to_date)
    csv_text = _render_csv(report_type, report_data)
    file_name = f"{report_type}_{station_id or organization_id or 'global'}.csv"
    filters = {
        "station_id": station_id,
        "organization_id": organization_id,
        "report_date": str(report_date) if report_date else None,
        "from_date": str(from_date) if from_date else None,
        "to_date": str(to_date) if to_date else None,
    }

    job = ReportExportJob(
        report_type=report_type,
        format="csv",
        status="completed",
        station_id=station_id,
        organization_id=organization_id,
        requested_by_user_id=current_user.id,
        filters_json=json.dumps(filters, sort_keys=True),
        file_name=file_name,
        content_type="text/csv",
        content_text=csv_text,
    )
    db.add(job)
    db.flush()
    log_audit_event(
        db,
        current_user=current_user,
        module="report_exports",
        action="report_exports.create",
        entity_type="report_export_job",
        entity_id=job.id,
        station_id=station_id,
        details={"report_type": report_type, "organization_id": organization_id, "file_name": file_name},
    )
    db.commit()
    db.refresh(job)
    return job


def ensure_export_access(job: ReportExportJob, current_user: User) -> None:
    role_name = current_user.role.name
    if role_name == "Admin":
        return
    user_organization_id = current_user.station.organization_id if current_user.station else None
    if role_name == "HeadOffice":
        if job.organization_id == user_organization_id:
            return
        raise HTTPException(status_code=403, detail="Not authorized for this report export")
    if job.station_id != current_user.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this report export")
