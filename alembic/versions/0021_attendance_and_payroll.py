"""attendance and payroll

Revision ID: 0021_attendance_and_payroll
Revises: 0020_hardware_vendor_connection_fields
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0021_attendance_and_payroll"
down_revision = "0020_hardware_vendor_connection_fields"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(sa.Column("monthly_salary", sa.Float(), nullable=False, server_default="0"))
        batch_op.add_column(sa.Column("payroll_enabled", sa.Boolean(), nullable=False, server_default=sa.true()))

    op.create_table(
        "attendance_records",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("station_id", sa.Integer(), sa.ForeignKey("stations.id"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("attendance_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="present"),
        sa.Column("check_in_at", sa.DateTime(), nullable=True),
        sa.Column("check_out_at", sa.DateTime(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("approved_by_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_attendance_records_station_id", "attendance_records", ["station_id"], unique=False)
    op.create_index("ix_attendance_records_user_id", "attendance_records", ["user_id"], unique=False)
    op.create_index("ix_attendance_records_attendance_date", "attendance_records", ["attendance_date"], unique=False)
    op.create_index("ix_attendance_records_status", "attendance_records", ["status"], unique=False)

    op.create_table(
        "payroll_runs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("station_id", sa.Integer(), sa.ForeignKey("stations.id"), nullable=False),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="draft"),
        sa.Column("total_staff", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_gross_amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("total_deductions", sa.Float(), nullable=False, server_default="0"),
        sa.Column("total_net_amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("generated_by_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("finalized_by_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("finalized_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_payroll_runs_station_id", "payroll_runs", ["station_id"], unique=False)
    op.create_index("ix_payroll_runs_period_start", "payroll_runs", ["period_start"], unique=False)
    op.create_index("ix_payroll_runs_period_end", "payroll_runs", ["period_end"], unique=False)
    op.create_index("ix_payroll_runs_status", "payroll_runs", ["status"], unique=False)

    op.create_table(
        "payroll_lines",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("payroll_run_id", sa.Integer(), sa.ForeignKey("payroll_runs.id"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("present_days", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("leave_days", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("absent_days", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("payable_days", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("monthly_salary", sa.Float(), nullable=False, server_default="0"),
        sa.Column("gross_amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("deductions", sa.Float(), nullable=False, server_default="0"),
        sa.Column("net_amount", sa.Float(), nullable=False, server_default="0"),
    )
    op.create_index("ix_payroll_lines_payroll_run_id", "payroll_lines", ["payroll_run_id"], unique=False)
    op.create_index("ix_payroll_lines_user_id", "payroll_lines", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_payroll_lines_user_id", table_name="payroll_lines")
    op.drop_index("ix_payroll_lines_payroll_run_id", table_name="payroll_lines")
    op.drop_table("payroll_lines")

    op.drop_index("ix_payroll_runs_status", table_name="payroll_runs")
    op.drop_index("ix_payroll_runs_period_end", table_name="payroll_runs")
    op.drop_index("ix_payroll_runs_period_start", table_name="payroll_runs")
    op.drop_index("ix_payroll_runs_station_id", table_name="payroll_runs")
    op.drop_table("payroll_runs")

    op.drop_index("ix_attendance_records_status", table_name="attendance_records")
    op.drop_index("ix_attendance_records_attendance_date", table_name="attendance_records")
    op.drop_index("ix_attendance_records_user_id", table_name="attendance_records")
    op.drop_index("ix_attendance_records_station_id", table_name="attendance_records")
    op.drop_table("attendance_records")

    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("payroll_enabled")
        batch_op.drop_column("monthly_salary")
