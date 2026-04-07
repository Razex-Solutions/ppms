"""profile payroll lines

Revision ID: 0025_profile_payroll_lines
Revises: 0024_brand_catalog_and_branding_inheritance
Create Date: 2026-04-08
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect, text


revision = "0025_profile_payroll_lines"
down_revision = "0024_brand_catalog_and_branding_inheritance"
branch_labels = None
depends_on = None


def _columns(table_name: str) -> set[str]:
    return {column["name"] for column in inspect(op.get_bind()).get_columns(table_name)}


def _drop_leftover_temp_tables() -> None:
    bind = op.get_bind()
    for table_name in inspect(bind).get_table_names():
        if table_name.startswith("_alembic_tmp_"):
            bind.execute(text(f'DROP TABLE "{table_name}"'))


def _rebuild_attendance_records() -> None:
    if "employee_profile_id" in _columns("attendance_records"):
        return
    bind = op.get_bind()
    bind.execute(
        text(
            """
            CREATE TABLE attendance_records_new (
                id INTEGER NOT NULL PRIMARY KEY,
                station_id INTEGER NOT NULL REFERENCES stations(id),
                user_id INTEGER REFERENCES users(id),
                employee_profile_id INTEGER REFERENCES employee_profiles(id),
                attendance_date DATE NOT NULL,
                status VARCHAR NOT NULL,
                check_in_at DATETIME,
                check_out_at DATETIME,
                notes TEXT,
                approved_by_user_id INTEGER REFERENCES users(id),
                created_at DATETIME NOT NULL,
                updated_at DATETIME NOT NULL
            )
            """
        )
    )
    bind.execute(
        text(
            """
            INSERT INTO attendance_records_new (
                id, station_id, user_id, attendance_date, status, check_in_at,
                check_out_at, notes, approved_by_user_id, created_at, updated_at
            )
            SELECT
                id, station_id, user_id, attendance_date, status, check_in_at,
                check_out_at, notes, approved_by_user_id, created_at, updated_at
            FROM attendance_records
            """
        )
    )
    bind.execute(text("DROP TABLE attendance_records"))
    bind.execute(text("ALTER TABLE attendance_records_new RENAME TO attendance_records"))
    bind.execute(text("CREATE INDEX ix_attendance_records_id ON attendance_records (id)"))
    bind.execute(text("CREATE INDEX ix_attendance_records_station_id ON attendance_records (station_id)"))
    bind.execute(text("CREATE INDEX ix_attendance_records_user_id ON attendance_records (user_id)"))
    bind.execute(text("CREATE INDEX ix_attendance_records_employee_profile_id ON attendance_records (employee_profile_id)"))
    bind.execute(text("CREATE INDEX ix_attendance_records_attendance_date ON attendance_records (attendance_date)"))
    bind.execute(text("CREATE INDEX ix_attendance_records_status ON attendance_records (status)"))


def _rebuild_salary_adjustments() -> None:
    if "employee_profile_id" in _columns("salary_adjustments"):
        return
    bind = op.get_bind()
    bind.execute(
        text(
            """
            CREATE TABLE salary_adjustments_new (
                id INTEGER NOT NULL PRIMARY KEY,
                station_id INTEGER NOT NULL REFERENCES stations(id),
                user_id INTEGER REFERENCES users(id),
                employee_profile_id INTEGER REFERENCES employee_profiles(id),
                effective_date DATE NOT NULL,
                impact VARCHAR NOT NULL,
                amount FLOAT NOT NULL,
                reason VARCHAR NOT NULL,
                notes TEXT,
                created_by_user_id INTEGER NOT NULL REFERENCES users(id),
                created_at DATETIME NOT NULL
            )
            """
        )
    )
    bind.execute(
        text(
            """
            INSERT INTO salary_adjustments_new (
                id, station_id, user_id, effective_date, impact, amount,
                reason, notes, created_by_user_id, created_at
            )
            SELECT
                id, station_id, user_id, effective_date, impact, amount,
                reason, notes, created_by_user_id, created_at
            FROM salary_adjustments
            """
        )
    )
    bind.execute(text("DROP TABLE salary_adjustments"))
    bind.execute(text("ALTER TABLE salary_adjustments_new RENAME TO salary_adjustments"))
    bind.execute(text("CREATE INDEX ix_salary_adjustments_id ON salary_adjustments (id)"))
    bind.execute(text("CREATE INDEX ix_salary_adjustments_station_id ON salary_adjustments (station_id)"))
    bind.execute(text("CREATE INDEX ix_salary_adjustments_user_id ON salary_adjustments (user_id)"))
    bind.execute(text("CREATE INDEX ix_salary_adjustments_employee_profile_id ON salary_adjustments (employee_profile_id)"))
    bind.execute(text("CREATE INDEX ix_salary_adjustments_effective_date ON salary_adjustments (effective_date)"))


def _rebuild_payroll_lines() -> None:
    if "employee_profile_id" in _columns("payroll_lines"):
        return
    bind = op.get_bind()
    bind.execute(
        text(
            """
            CREATE TABLE payroll_lines_new (
                id INTEGER NOT NULL PRIMARY KEY,
                payroll_run_id INTEGER NOT NULL REFERENCES payroll_runs(id),
                user_id INTEGER REFERENCES users(id),
                employee_profile_id INTEGER REFERENCES employee_profiles(id),
                present_days INTEGER NOT NULL,
                leave_days INTEGER NOT NULL,
                absent_days INTEGER NOT NULL,
                payable_days INTEGER NOT NULL,
                monthly_salary FLOAT NOT NULL,
                gross_amount FLOAT NOT NULL,
                attendance_deductions FLOAT NOT NULL,
                adjustment_additions FLOAT NOT NULL,
                adjustment_deductions FLOAT NOT NULL,
                deductions FLOAT NOT NULL,
                net_amount FLOAT NOT NULL
            )
            """
        )
    )
    bind.execute(
        text(
            """
            INSERT INTO payroll_lines_new (
                id, payroll_run_id, user_id, present_days, leave_days, absent_days,
                payable_days, monthly_salary, gross_amount, attendance_deductions,
                adjustment_additions, adjustment_deductions, deductions, net_amount
            )
            SELECT
                id, payroll_run_id, user_id, present_days, leave_days, absent_days,
                payable_days, monthly_salary, gross_amount, attendance_deductions,
                adjustment_additions, adjustment_deductions, deductions, net_amount
            FROM payroll_lines
            """
        )
    )
    bind.execute(text("DROP TABLE payroll_lines"))
    bind.execute(text("ALTER TABLE payroll_lines_new RENAME TO payroll_lines"))
    bind.execute(text("CREATE INDEX ix_payroll_lines_id ON payroll_lines (id)"))
    bind.execute(text("CREATE INDEX ix_payroll_lines_payroll_run_id ON payroll_lines (payroll_run_id)"))
    bind.execute(text("CREATE INDEX ix_payroll_lines_user_id ON payroll_lines (user_id)"))
    bind.execute(text("CREATE INDEX ix_payroll_lines_employee_profile_id ON payroll_lines (employee_profile_id)"))


def upgrade() -> None:
    _drop_leftover_temp_tables()
    _rebuild_attendance_records()
    _rebuild_salary_adjustments()
    _rebuild_payroll_lines()


def downgrade() -> None:
    # This migration is intentionally forward-only for local Phase 9 acceptance data.
    pass
