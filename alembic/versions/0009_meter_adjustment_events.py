"""add meter adjustment events

Revision ID: 0009_meter_adjustment_events
Revises: 0008_tanker_operations_module
Create Date: 2026-04-03 18:45:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0009_meter_adjustment_events"
down_revision = "0008_tanker_operations_module"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = inspect(op.get_bind())
    nozzle_columns = {column["name"] for column in inspector.get_columns("nozzles")}

    if "current_segment_start_reading" not in nozzle_columns:
        op.add_column("nozzles", sa.Column("current_segment_start_reading", sa.Float(), nullable=True))
    if "current_segment_started_at" not in nozzle_columns:
        op.add_column("nozzles", sa.Column("current_segment_started_at", sa.DateTime(), nullable=True))

    op.execute("UPDATE nozzles SET current_segment_start_reading = meter_reading WHERE current_segment_start_reading IS NULL")
    op.execute("UPDATE nozzles SET current_segment_started_at = CURRENT_TIMESTAMP WHERE current_segment_started_at IS NULL")
    with op.batch_alter_table("nozzles") as batch_op:
        if "current_segment_start_reading" in {column["name"] for column in inspector.get_columns("nozzles")}:
            batch_op.alter_column("current_segment_start_reading", existing_type=sa.Float(), nullable=False)
        if "current_segment_started_at" in {column["name"] for column in inspector.get_columns("nozzles")}:
            batch_op.alter_column("current_segment_started_at", existing_type=sa.DateTime(), nullable=False)

    inspector = inspect(op.get_bind())
    if "meter_adjustment_events" not in inspector.get_table_names():
        op.create_table(
            "meter_adjustment_events",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("nozzle_id", sa.Integer(), nullable=False),
            sa.Column("station_id", sa.Integer(), nullable=False),
            sa.Column("old_reading", sa.Float(), nullable=False),
            sa.Column("new_reading", sa.Float(), nullable=False),
            sa.Column("reason", sa.String(), nullable=False),
            sa.Column("adjusted_by_user_id", sa.Integer(), nullable=False),
            sa.Column("adjusted_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["adjusted_by_user_id"], ["users.id"]),
            sa.ForeignKeyConstraint(["nozzle_id"], ["nozzles.id"]),
            sa.ForeignKeyConstraint(["station_id"], ["stations.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
    inspector = inspect(op.get_bind())
    existing_indexes = {index["name"] for index in inspector.get_indexes("meter_adjustment_events")}
    for index_name, column_name in [
        (op.f("ix_meter_adjustment_events_id"), "id"),
        (op.f("ix_meter_adjustment_events_nozzle_id"), "nozzle_id"),
        (op.f("ix_meter_adjustment_events_station_id"), "station_id"),
        (op.f("ix_meter_adjustment_events_adjusted_by_user_id"), "adjusted_by_user_id"),
        (op.f("ix_meter_adjustment_events_adjusted_at"), "adjusted_at"),
    ]:
        if index_name not in existing_indexes:
            op.create_index(index_name, "meter_adjustment_events", [column_name], unique=False)

    op.execute(
        """
        INSERT INTO station_module_settings (station_id, module_name, is_enabled)
        SELECT s.id, 'meter_adjustments', 1
        FROM stations s
        WHERE NOT EXISTS (
            SELECT 1
            FROM station_module_settings sms
            WHERE sms.station_id = s.id AND sms.module_name = 'meter_adjustments'
        )
        """
    )


def downgrade() -> None:
    inspector = inspect(op.get_bind())
    if "station_module_settings" in inspector.get_table_names():
        op.execute("DELETE FROM station_module_settings WHERE module_name = 'meter_adjustments'")
    if "meter_adjustment_events" in inspector.get_table_names():
        existing_indexes = {index["name"] for index in inspector.get_indexes("meter_adjustment_events")}
        for index_name in [
            op.f("ix_meter_adjustment_events_adjusted_at"),
            op.f("ix_meter_adjustment_events_adjusted_by_user_id"),
            op.f("ix_meter_adjustment_events_station_id"),
            op.f("ix_meter_adjustment_events_nozzle_id"),
            op.f("ix_meter_adjustment_events_id"),
        ]:
            if index_name in existing_indexes:
                op.drop_index(index_name, table_name="meter_adjustment_events")
        op.drop_table("meter_adjustment_events")
    nozzle_columns = {column["name"] for column in inspector.get_columns("nozzles")}
    if "current_segment_started_at" in nozzle_columns:
        op.drop_column("nozzles", "current_segment_started_at")
    if "current_segment_start_reading" in nozzle_columns:
        op.drop_column("nozzles", "current_segment_start_reading")
