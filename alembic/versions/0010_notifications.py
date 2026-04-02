"""add notifications

Revision ID: 0010_notifications
Revises: 0009_meter_adjustment_events
Create Date: 2026-04-03 19:20:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0010_notifications"
down_revision = "0009_meter_adjustment_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = inspect(op.get_bind())
    if "notifications" not in inspector.get_table_names():
        op.create_table(
            "notifications",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("recipient_user_id", sa.Integer(), nullable=False),
            sa.Column("actor_user_id", sa.Integer(), nullable=True),
            sa.Column("station_id", sa.Integer(), nullable=True),
            sa.Column("organization_id", sa.Integer(), nullable=True),
            sa.Column("event_type", sa.String(), nullable=False),
            sa.Column("title", sa.String(), nullable=False),
            sa.Column("message", sa.Text(), nullable=False),
            sa.Column("entity_type", sa.String(), nullable=True),
            sa.Column("entity_id", sa.Integer(), nullable=True),
            sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.text("0")),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("read_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["recipient_user_id"], ["users.id"]),
            sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"]),
            sa.ForeignKeyConstraint(["station_id"], ["stations.id"]),
            sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
    inspector = inspect(op.get_bind())
    existing_indexes = {index["name"] for index in inspector.get_indexes("notifications")}
    for index_name, column_name in [
        ("ix_notifications_id", "id"),
        ("ix_notifications_recipient_user_id", "recipient_user_id"),
        ("ix_notifications_actor_user_id", "actor_user_id"),
        ("ix_notifications_station_id", "station_id"),
        ("ix_notifications_organization_id", "organization_id"),
        ("ix_notifications_event_type", "event_type"),
        ("ix_notifications_entity_type", "entity_type"),
        ("ix_notifications_entity_id", "entity_id"),
        ("ix_notifications_is_read", "is_read"),
        ("ix_notifications_created_at", "created_at"),
    ]:
        if index_name not in existing_indexes:
            op.create_index(index_name, "notifications", [column_name], unique=False)


def downgrade() -> None:
    inspector = inspect(op.get_bind())
    if "notifications" in inspector.get_table_names():
        existing_indexes = {index["name"] for index in inspector.get_indexes("notifications")}
        for index_name in [
            "ix_notifications_created_at",
            "ix_notifications_is_read",
            "ix_notifications_entity_id",
            "ix_notifications_entity_type",
            "ix_notifications_event_type",
            "ix_notifications_organization_id",
            "ix_notifications_station_id",
            "ix_notifications_actor_user_id",
            "ix_notifications_recipient_user_id",
            "ix_notifications_id",
        ]:
            if index_name in existing_indexes:
                op.drop_index(index_name, table_name="notifications")
        op.drop_table("notifications")
