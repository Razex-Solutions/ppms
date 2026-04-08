"""tank calibration charts

Revision ID: 0027_tank_calibration_charts
Revises: 0026_shift_nozzle_snapshots
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0027_tank_calibration_charts"
down_revision = "0026_shift_nozzle_snapshots"
branch_labels = None
depends_on = None


def _tables() -> set[str]:
    return set(inspect(op.get_bind()).get_table_names())


def _ensure_index(table_name: str, index_name: str, columns: list[str]) -> None:
    bind = op.get_bind()
    existing_indexes = {index["name"] for index in inspect(bind).get_indexes(table_name)}
    if index_name not in existing_indexes:
        op.create_index(index_name, table_name, columns, unique=False)


def upgrade() -> None:
    tables = _tables()
    if "tank_calibration_charts" not in tables:
        op.create_table(
            "tank_calibration_charts",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("tank_id", sa.Integer(), sa.ForeignKey("tanks.id"), nullable=False),
            sa.Column("version_no", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("source_type", sa.String(), nullable=False, server_default="manual"),
            sa.Column("document_reference", sa.String(), nullable=True),
            sa.Column("notes", sa.String(), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("created_by_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        )
    _ensure_index("tank_calibration_charts", "ix_tank_calibration_charts_id", ["id"])
    _ensure_index("tank_calibration_charts", "ix_tank_calibration_charts_tank_id", ["tank_id"])

    if "tank_calibration_chart_lines" not in tables:
        op.create_table(
            "tank_calibration_chart_lines",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("chart_id", sa.Integer(), sa.ForeignKey("tank_calibration_charts.id"), nullable=False),
            sa.Column("dip_mm", sa.Float(), nullable=False),
            sa.Column("volume_liters", sa.Float(), nullable=False),
            sa.Column("water_mm", sa.Float(), nullable=True),
            sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        )
    _ensure_index("tank_calibration_chart_lines", "ix_tank_calibration_chart_lines_id", ["id"])
    _ensure_index("tank_calibration_chart_lines", "ix_tank_calibration_chart_lines_chart_id", ["chart_id"])


def downgrade() -> None:
    op.drop_index("ix_tank_calibration_chart_lines_chart_id", table_name="tank_calibration_chart_lines")
    op.drop_index("ix_tank_calibration_chart_lines_id", table_name="tank_calibration_chart_lines")
    op.drop_table("tank_calibration_chart_lines")
    op.drop_index("ix_tank_calibration_charts_tank_id", table_name="tank_calibration_charts")
    op.drop_index("ix_tank_calibration_charts_id", table_name="tank_calibration_charts")
    op.drop_table("tank_calibration_charts")
