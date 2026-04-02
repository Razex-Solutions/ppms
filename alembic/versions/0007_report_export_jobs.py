"""add report export jobs

Revision ID: 0007_report_export_jobs
Revises: 0006_customer_credit_overrides
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0007_report_export_jobs"
down_revision = "0006_customer_credit_overrides"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = inspect(op.get_bind())
    if "report_export_jobs" not in inspector.get_table_names():
        op.create_table(
            "report_export_jobs",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("report_type", sa.String(), nullable=False),
            sa.Column("format", sa.String(), nullable=False),
            sa.Column("status", sa.String(), nullable=False),
            sa.Column("station_id", sa.Integer(), nullable=True),
            sa.Column("organization_id", sa.Integer(), nullable=True),
            sa.Column("requested_by_user_id", sa.Integer(), nullable=True),
            sa.Column("filters_json", sa.Text(), nullable=True),
            sa.Column("file_name", sa.String(), nullable=False),
            sa.Column("content_type", sa.String(), nullable=False),
            sa.Column("content_text", sa.Text(), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["station_id"], ["stations.id"]),
            sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"]),
            sa.ForeignKeyConstraint(["requested_by_user_id"], ["users.id"]),
        )
    existing_indexes = {index["name"] for index in inspector.get_indexes("report_export_jobs")}
    for index_name, column_name in [
        ("ix_report_export_jobs_report_type", "report_type"),
        ("ix_report_export_jobs_status", "status"),
        ("ix_report_export_jobs_station_id", "station_id"),
        ("ix_report_export_jobs_organization_id", "organization_id"),
        ("ix_report_export_jobs_requested_by_user_id", "requested_by_user_id"),
        ("ix_report_export_jobs_created_at", "created_at"),
    ]:
        if index_name not in existing_indexes:
            op.create_index(index_name, "report_export_jobs", [column_name], unique=False)


def downgrade() -> None:
    inspector = inspect(op.get_bind())
    if "report_export_jobs" in inspector.get_table_names():
        existing_indexes = {index["name"] for index in inspector.get_indexes("report_export_jobs")}
        for index_name in [
            "ix_report_export_jobs_created_at",
            "ix_report_export_jobs_requested_by_user_id",
            "ix_report_export_jobs_organization_id",
            "ix_report_export_jobs_station_id",
            "ix_report_export_jobs_status",
            "ix_report_export_jobs_report_type",
        ]:
            if index_name in existing_indexes:
                op.drop_index(index_name, table_name="report_export_jobs")
        op.drop_table("report_export_jobs")
