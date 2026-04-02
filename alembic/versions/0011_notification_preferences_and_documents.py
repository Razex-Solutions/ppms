"""add notification preferences and financial documents

Revision ID: 0011_notification_preferences_and_documents
Revises: 0010_notifications
Create Date: 2026-04-03 20:10:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0011_notification_preferences_and_documents"
down_revision = "0010_notifications"
branch_labels = None
depends_on = None


def _create_indexes(table_name: str, specs: list[tuple[str, str]]) -> None:
    inspector = inspect(op.get_bind())
    existing = {index["name"] for index in inspector.get_indexes(table_name)}
    for index_name, column_name in specs:
        if index_name not in existing:
            op.create_index(index_name, table_name, [column_name], unique=False)


def upgrade() -> None:
    inspector = inspect(op.get_bind())
    user_columns = {column["name"] for column in inspector.get_columns("users")}
    if "phone" not in user_columns:
        op.add_column("users", sa.Column("phone", sa.String(), nullable=True))
    if "whatsapp_number" not in user_columns:
        op.add_column("users", sa.Column("whatsapp_number", sa.String(), nullable=True))

    if "notification_preferences" not in inspector.get_table_names():
        op.create_table(
            "notification_preferences",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("event_type", sa.String(), nullable=False),
            sa.Column("in_app_enabled", sa.Boolean(), nullable=False, server_default=sa.text("1")),
            sa.Column("email_enabled", sa.Boolean(), nullable=False, server_default=sa.text("0")),
            sa.Column("sms_enabled", sa.Boolean(), nullable=False, server_default=sa.text("0")),
            sa.Column("whatsapp_enabled", sa.Boolean(), nullable=False, server_default=sa.text("0")),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
    _create_indexes(
        "notification_preferences",
        [
            ("ix_notification_preferences_id", "id"),
            ("ix_notification_preferences_user_id", "user_id"),
            ("ix_notification_preferences_event_type", "event_type"),
        ],
    )

    inspector = inspect(op.get_bind())
    if "notification_deliveries" not in inspector.get_table_names():
        op.create_table(
            "notification_deliveries",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("notification_id", sa.Integer(), nullable=False),
            sa.Column("channel", sa.String(), nullable=False),
            sa.Column("destination", sa.String(), nullable=True),
            sa.Column("status", sa.String(), nullable=False),
            sa.Column("detail", sa.String(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["notification_id"], ["notifications.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
    _create_indexes(
        "notification_deliveries",
        [
            ("ix_notification_deliveries_id", "id"),
            ("ix_notification_deliveries_notification_id", "notification_id"),
            ("ix_notification_deliveries_channel", "channel"),
            ("ix_notification_deliveries_status", "status"),
            ("ix_notification_deliveries_created_at", "created_at"),
        ],
    )

    inspector = inspect(op.get_bind())
    if "invoice_profiles" not in inspector.get_table_names():
        op.create_table(
            "invoice_profiles",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("station_id", sa.Integer(), nullable=False),
            sa.Column("business_name", sa.String(), nullable=False),
            sa.Column("logo_url", sa.String(), nullable=True),
            sa.Column("tax_label_1", sa.String(), nullable=True),
            sa.Column("tax_value_1", sa.String(), nullable=True),
            sa.Column("tax_label_2", sa.String(), nullable=True),
            sa.Column("tax_value_2", sa.String(), nullable=True),
            sa.Column("contact_email", sa.String(), nullable=True),
            sa.Column("contact_phone", sa.String(), nullable=True),
            sa.Column("footer_text", sa.Text(), nullable=True),
            sa.Column("invoice_prefix", sa.String(), nullable=True),
            sa.ForeignKeyConstraint(["station_id"], ["stations.id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("station_id"),
        )
    _create_indexes(
        "invoice_profiles",
        [
            ("ix_invoice_profiles_id", "id"),
            ("ix_invoice_profiles_station_id", "station_id"),
        ],
    )

    inspector = inspect(op.get_bind())
    if "financial_document_dispatches" not in inspector.get_table_names():
        op.create_table(
            "financial_document_dispatches",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("station_id", sa.Integer(), nullable=False),
            sa.Column("requested_by_user_id", sa.Integer(), nullable=False),
            sa.Column("document_type", sa.String(), nullable=False),
            sa.Column("entity_type", sa.String(), nullable=False),
            sa.Column("entity_id", sa.Integer(), nullable=False),
            sa.Column("channel", sa.String(), nullable=False),
            sa.Column("recipient_name", sa.String(), nullable=True),
            sa.Column("recipient_contact", sa.String(), nullable=True),
            sa.Column("status", sa.String(), nullable=False),
            sa.Column("detail", sa.String(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["station_id"], ["stations.id"]),
            sa.ForeignKeyConstraint(["requested_by_user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
    _create_indexes(
        "financial_document_dispatches",
        [
            ("ix_financial_document_dispatches_id", "id"),
            ("ix_financial_document_dispatches_station_id", "station_id"),
            ("ix_financial_document_dispatches_requested_by_user_id", "requested_by_user_id"),
            ("ix_financial_document_dispatches_document_type", "document_type"),
            ("ix_financial_document_dispatches_entity_type", "entity_type"),
            ("ix_financial_document_dispatches_entity_id", "entity_id"),
            ("ix_financial_document_dispatches_channel", "channel"),
            ("ix_financial_document_dispatches_status", "status"),
            ("ix_financial_document_dispatches_created_at", "created_at"),
        ],
    )


def downgrade() -> None:
    inspector = inspect(op.get_bind())
    if "financial_document_dispatches" in inspector.get_table_names():
        for index_name in [
            "ix_financial_document_dispatches_created_at",
            "ix_financial_document_dispatches_status",
            "ix_financial_document_dispatches_channel",
            "ix_financial_document_dispatches_entity_id",
            "ix_financial_document_dispatches_entity_type",
            "ix_financial_document_dispatches_document_type",
            "ix_financial_document_dispatches_requested_by_user_id",
            "ix_financial_document_dispatches_station_id",
            "ix_financial_document_dispatches_id",
        ]:
            op.drop_index(index_name, table_name="financial_document_dispatches")
        op.drop_table("financial_document_dispatches")
    inspector = inspect(op.get_bind())
    if "invoice_profiles" in inspector.get_table_names():
        op.drop_index("ix_invoice_profiles_station_id", table_name="invoice_profiles")
        op.drop_index("ix_invoice_profiles_id", table_name="invoice_profiles")
        op.drop_table("invoice_profiles")
    inspector = inspect(op.get_bind())
    if "notification_deliveries" in inspector.get_table_names():
        for index_name in [
            "ix_notification_deliveries_created_at",
            "ix_notification_deliveries_status",
            "ix_notification_deliveries_channel",
            "ix_notification_deliveries_notification_id",
            "ix_notification_deliveries_id",
        ]:
            op.drop_index(index_name, table_name="notification_deliveries")
        op.drop_table("notification_deliveries")
    inspector = inspect(op.get_bind())
    if "notification_preferences" in inspector.get_table_names():
        for index_name in [
            "ix_notification_preferences_event_type",
            "ix_notification_preferences_user_id",
            "ix_notification_preferences_id",
        ]:
            op.drop_index(index_name, table_name="notification_preferences")
        op.drop_table("notification_preferences")
    user_columns = {column["name"] for column in inspector.get_columns("users")}
    if "whatsapp_number" in user_columns:
        op.drop_column("users", "whatsapp_number")
    if "phone" in user_columns:
        op.drop_column("users", "phone")
