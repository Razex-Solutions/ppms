"""staff titles and forecourt activation

Revision ID: 0028_staff_titles_forecourt
Revises: 0027_tank_calibration_charts
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0028_staff_titles_forecourt"
down_revision = "0027_tank_calibration_charts"
branch_labels = None
depends_on = None


def _columns(table_name: str) -> set[str]:
    return {column["name"] for column in inspect(op.get_bind()).get_columns(table_name)}


def _indexes(table_name: str) -> set[str]:
    return {index["name"] for index in inspect(op.get_bind()).get_indexes(table_name)}


def _ensure_column(table_name: str, column: sa.Column) -> None:
    if column.name not in _columns(table_name):
        op.add_column(table_name, column)


def _ensure_index(table_name: str, index_name: str, columns: list[str]) -> None:
    if index_name not in _indexes(table_name):
        op.create_index(index_name, table_name, columns, unique=False)


def upgrade() -> None:
    _ensure_column("employee_profiles", sa.Column("staff_title", sa.String(), nullable=True))
    _ensure_index("employee_profiles", "ix_employee_profiles_staff_title", ["staff_title"])

    _ensure_column("tanks", sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()))
    _ensure_column("dispensers", sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()))
    _ensure_column("nozzles", sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()))


def downgrade() -> None:
    if "ix_employee_profiles_staff_title" in _indexes("employee_profiles"):
        op.drop_index("ix_employee_profiles_staff_title", table_name="employee_profiles")
    if "staff_title" in _columns("employee_profiles"):
        op.drop_column("employee_profiles", "staff_title")
    if "is_active" in _columns("nozzles"):
        op.drop_column("nozzles", "is_active")
    if "is_active" in _columns("dispensers"):
        op.drop_column("dispensers", "is_active")
    if "is_active" in _columns("tanks"):
        op.drop_column("tanks", "is_active")
