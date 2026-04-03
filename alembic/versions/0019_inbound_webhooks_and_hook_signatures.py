"""inbound webhooks and hook signatures

Revision ID: 0019_inbound_webhooks_and_hook_signatures
Revises: 0018_auth_sessions_and_lockout
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0019_inbound_webhooks_and_hook_signatures"
down_revision = "0018_auth_sessions_and_lockout"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("online_api_hooks") as batch_op:
        batch_op.add_column(sa.Column("signature_header", sa.String(), nullable=True))

    op.create_table(
        "inbound_webhook_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("organization_id", sa.Integer(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("hook_name", sa.String(), nullable=False),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column("source", sa.String(), nullable=False, server_default="external"),
        sa.Column("headers_json", sa.Text(), nullable=True),
        sa.Column("payload_json", sa.Text(), nullable=True),
        sa.Column("status", sa.String(), nullable=False, server_default="received"),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column("received_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_inbound_webhook_events_organization_id", "inbound_webhook_events", ["organization_id"], unique=False)
    op.create_index("ix_inbound_webhook_events_hook_name", "inbound_webhook_events", ["hook_name"], unique=False)
    op.create_index("ix_inbound_webhook_events_event_type", "inbound_webhook_events", ["event_type"], unique=False)
    op.create_index("ix_inbound_webhook_events_status", "inbound_webhook_events", ["status"], unique=False)
    op.create_index("ix_inbound_webhook_events_received_at", "inbound_webhook_events", ["received_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_inbound_webhook_events_received_at", table_name="inbound_webhook_events")
    op.drop_index("ix_inbound_webhook_events_status", table_name="inbound_webhook_events")
    op.drop_index("ix_inbound_webhook_events_event_type", table_name="inbound_webhook_events")
    op.drop_index("ix_inbound_webhook_events_hook_name", table_name="inbound_webhook_events")
    op.drop_index("ix_inbound_webhook_events_organization_id", table_name="inbound_webhook_events")
    op.drop_table("inbound_webhook_events")

    with op.batch_alter_table("online_api_hooks") as batch_op:
        batch_op.drop_column("signature_header")
