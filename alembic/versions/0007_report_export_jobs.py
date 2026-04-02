"""add report export jobs

Revision ID: 0007_report_export_jobs
Revises: 0006_customer_credit_overrides
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0007_report_export_jobs"
down_revision = "0006_customer_credit_overrides"
branch_labels = None
depends_on = None


def upgrade() -> None:
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
    op.create_index("ix_report_export_jobs_report_type", "report_export_jobs", ["report_type"], unique=False)
    op.create_index("ix_report_export_jobs_status", "report_export_jobs", ["status"], unique=False)
    op.create_index("ix_report_export_jobs_station_id", "report_export_jobs", ["station_id"], unique=False)
    op.create_index("ix_report_export_jobs_organization_id", "report_export_jobs", ["organization_id"], unique=False)
    op.create_index("ix_report_export_jobs_requested_by_user_id", "report_export_jobs", ["requested_by_user_id"], unique=False)
    op.create_index("ix_report_export_jobs_created_at", "report_export_jobs", ["created_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_report_export_jobs_created_at", table_name="report_export_jobs")
    op.drop_index("ix_report_export_jobs_requested_by_user_id", table_name="report_export_jobs")
    op.drop_index("ix_report_export_jobs_organization_id", table_name="report_export_jobs")
    op.drop_index("ix_report_export_jobs_station_id", table_name="report_export_jobs")
    op.drop_index("ix_report_export_jobs_status", table_name="report_export_jobs")
    op.drop_index("ix_report_export_jobs_report_type", table_name="report_export_jobs")
    op.drop_table("report_export_jobs")
