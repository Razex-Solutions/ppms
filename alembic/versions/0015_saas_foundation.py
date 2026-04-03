"""saas foundation

Revision ID: 0015_saas_foundation
Revises: 0014_document_templates
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0015_saas_foundation"
down_revision = "0014_document_templates"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "subscription_plans",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("monthly_price", sa.Float(), nullable=False, server_default="0"),
        sa.Column("yearly_price", sa.Float(), nullable=True),
        sa.Column("max_stations", sa.Integer(), nullable=True),
        sa.Column("max_users", sa.Integer(), nullable=True),
        sa.Column("feature_summary", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.UniqueConstraint("code", name="uq_subscription_plans_code"),
    )
    op.create_index("ix_subscription_plans_name", "subscription_plans", ["name"], unique=False)
    op.create_index("ix_subscription_plans_code", "subscription_plans", ["code"], unique=False)

    op.create_table(
        "organization_subscriptions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("organization_id", sa.Integer(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("plan_id", sa.Integer(), sa.ForeignKey("subscription_plans.id"), nullable=True),
        sa.Column("status", sa.String(), nullable=False, server_default="inactive"),
        sa.Column("billing_cycle", sa.String(), nullable=False, server_default="monthly"),
        sa.Column("start_date", sa.DateTime(), nullable=True),
        sa.Column("end_date", sa.DateTime(), nullable=True),
        sa.Column("trial_ends_at", sa.DateTime(), nullable=True),
        sa.Column("auto_renew", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("price_override", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("organization_id", name="uq_organization_subscriptions_organization_id"),
    )
    op.create_index("ix_organization_subscriptions_organization_id", "organization_subscriptions", ["organization_id"], unique=False)
    op.create_index("ix_organization_subscriptions_plan_id", "organization_subscriptions", ["plan_id"], unique=False)
    op.create_index("ix_organization_subscriptions_status", "organization_subscriptions", ["status"], unique=False)

    op.create_table(
        "organization_module_settings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("organization_id", sa.Integer(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("module_name", sa.String(), nullable=False),
        sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index("ix_organization_module_settings_organization_id", "organization_module_settings", ["organization_id"], unique=False)
    op.create_index("ix_organization_module_settings_module_name", "organization_module_settings", ["module_name"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_organization_module_settings_module_name", table_name="organization_module_settings")
    op.drop_index("ix_organization_module_settings_organization_id", table_name="organization_module_settings")
    op.drop_table("organization_module_settings")

    op.drop_index("ix_organization_subscriptions_status", table_name="organization_subscriptions")
    op.drop_index("ix_organization_subscriptions_plan_id", table_name="organization_subscriptions")
    op.drop_index("ix_organization_subscriptions_organization_id", table_name="organization_subscriptions")
    op.drop_table("organization_subscriptions")

    op.drop_index("ix_subscription_plans_code", table_name="subscription_plans")
    op.drop_index("ix_subscription_plans_name", table_name="subscription_plans")
    op.drop_table("subscription_plans")
