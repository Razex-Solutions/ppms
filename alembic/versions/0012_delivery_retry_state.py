"""delivery retry state

Revision ID: 0012_delivery_retry_state
Revises: 0011_notification_preferences_and_documents
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0012_delivery_retry_state"
down_revision = "0011_notification_preferences_and_documents"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = inspect(op.get_bind())

    with op.batch_alter_table("notification_deliveries") as batch_op:
        notification_columns = {
            column["name"] for column in inspector.get_columns("notification_deliveries")
        }
        notification_indexes = {
            index["name"] for index in inspector.get_indexes("notification_deliveries")
        }
        if "attempts_count" not in notification_columns:
            batch_op.add_column(sa.Column("attempts_count", sa.Integer(), nullable=False, server_default="0"))
        if "last_attempt_at" not in notification_columns:
            batch_op.add_column(sa.Column("last_attempt_at", sa.DateTime(), nullable=True))
        if "next_retry_at" not in notification_columns:
            batch_op.add_column(sa.Column("next_retry_at", sa.DateTime(), nullable=True))
        if "processed_at" not in notification_columns:
            batch_op.add_column(sa.Column("processed_at", sa.DateTime(), nullable=True))
        if "ix_notification_deliveries_next_retry_at" not in notification_indexes:
            batch_op.create_index("ix_notification_deliveries_next_retry_at", ["next_retry_at"], unique=False)

    with op.batch_alter_table("financial_document_dispatches") as batch_op:
        dispatch_columns = {
            column["name"] for column in inspector.get_columns("financial_document_dispatches")
        }
        dispatch_indexes = {
            index["name"] for index in inspector.get_indexes("financial_document_dispatches")
        }
        if "output_format" not in dispatch_columns:
            batch_op.add_column(sa.Column("output_format", sa.String(), nullable=False, server_default="pdf"))
        if "attempts_count" not in dispatch_columns:
            batch_op.add_column(sa.Column("attempts_count", sa.Integer(), nullable=False, server_default="0"))
        if "last_attempt_at" not in dispatch_columns:
            batch_op.add_column(sa.Column("last_attempt_at", sa.DateTime(), nullable=True))
        if "next_retry_at" not in dispatch_columns:
            batch_op.add_column(sa.Column("next_retry_at", sa.DateTime(), nullable=True))
        if "processed_at" not in dispatch_columns:
            batch_op.add_column(sa.Column("processed_at", sa.DateTime(), nullable=True))
        if "ix_financial_document_dispatches_next_retry_at" not in dispatch_indexes:
            batch_op.create_index("ix_financial_document_dispatches_next_retry_at", ["next_retry_at"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("financial_document_dispatches") as batch_op:
        batch_op.drop_index("ix_financial_document_dispatches_next_retry_at")
        batch_op.drop_column("processed_at")
        batch_op.drop_column("next_retry_at")
        batch_op.drop_column("last_attempt_at")
        batch_op.drop_column("attempts_count")
        batch_op.drop_column("output_format")

    with op.batch_alter_table("notification_deliveries") as batch_op:
        batch_op.drop_index("ix_notification_deliveries_next_retry_at")
        batch_op.drop_column("processed_at")
        batch_op.drop_column("next_retry_at")
        batch_op.drop_column("last_attempt_at")
        batch_op.drop_column("attempts_count")
