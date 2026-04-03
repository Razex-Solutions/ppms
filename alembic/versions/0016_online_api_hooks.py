"""online api hooks

Revision ID: 0016_online_api_hooks
Revises: 0015_saas_foundation
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0016_online_api_hooks"
down_revision = "0015_saas_foundation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "online_api_hooks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("organization_id", sa.Integer(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column("target_url", sa.String(), nullable=False),
        sa.Column("auth_type", sa.String(), nullable=False, server_default="none"),
        sa.Column("auth_token", sa.Text(), nullable=True),
        sa.Column("secret_key", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("last_status", sa.String(), nullable=True),
        sa.Column("last_detail", sa.Text(), nullable=True),
        sa.Column("last_triggered_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_online_api_hooks_organization_id", "online_api_hooks", ["organization_id"], unique=False)
    op.create_index("ix_online_api_hooks_event_type", "online_api_hooks", ["event_type"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_online_api_hooks_event_type", table_name="online_api_hooks")
    op.drop_index("ix_online_api_hooks_organization_id", table_name="online_api_hooks")
    op.drop_table("online_api_hooks")
