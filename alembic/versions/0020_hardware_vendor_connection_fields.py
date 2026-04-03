"""hardware vendor connection fields

Revision ID: 0020_hardware_vendor_connection_fields
Revises: 0019_inbound_webhooks_and_hook_signatures
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0020_hardware_vendor_connection_fields"
down_revision = "0019_inbound_webhooks_and_hook_signatures"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("hardware_devices") as batch_op:
        batch_op.add_column(sa.Column("protocol", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("endpoint_url", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("device_identifier", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("api_key", sa.String(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("hardware_devices") as batch_op:
        batch_op.drop_column("api_key")
        batch_op.drop_column("device_identifier")
        batch_op.drop_column("endpoint_url")
        batch_op.drop_column("protocol")
