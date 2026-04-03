"""platform foundation and station setup

Revision ID: 0022_platform_foundation_and_station_setup
Revises: 0021_attendance_and_payroll
Create Date: 2026-04-04
"""

from alembic import op
import sqlalchemy as sa


revision = "0022_platform_foundation_and_station_setup"
down_revision = "0021_attendance_and_payroll"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("organizations") as batch_op:
        batch_op.add_column(sa.Column("legal_name", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("brand_name", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("brand_code", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("logo_url", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("contact_email", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("contact_phone", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("registration_number", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("tax_registration_number", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("onboarding_status", sa.String(), nullable=False, server_default="draft"))
        batch_op.add_column(sa.Column("billing_status", sa.String(), nullable=False, server_default="trial"))
        batch_op.add_column(sa.Column("station_target_count", sa.Integer(), nullable=True))
        batch_op.add_column(
            sa.Column("inherit_branding_to_stations", sa.Boolean(), nullable=False, server_default=sa.true())
        )

    op.create_index("ix_organizations_brand_name", "organizations", ["brand_name"], unique=False)
    op.create_index("ix_organizations_brand_code", "organizations", ["brand_code"], unique=False)
    op.create_index("ix_organizations_onboarding_status", "organizations", ["onboarding_status"], unique=False)
    op.create_index("ix_organizations_billing_status", "organizations", ["billing_status"], unique=False)

    with op.batch_alter_table("stations") as batch_op:
        batch_op.add_column(sa.Column("display_name", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("legal_name_override", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("logo_url", sa.String(), nullable=True))
        batch_op.add_column(
            sa.Column("use_organization_branding", sa.Boolean(), nullable=False, server_default=sa.true())
        )
        batch_op.add_column(sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()))
        batch_op.add_column(sa.Column("setup_status", sa.String(), nullable=False, server_default="draft"))
        batch_op.add_column(sa.Column("setup_completed_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("has_shops", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("has_pos", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("has_tankers", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("has_hardware", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(
            sa.Column("allow_meter_adjustments", sa.Boolean(), nullable=False, server_default=sa.true())
        )
        batch_op.add_column(sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")))

    op.create_index("ix_stations_setup_status", "stations", ["setup_status"], unique=False)

    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(sa.Column("organization_id", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("created_by_user_id", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("scope_level", sa.String(), nullable=False, server_default="station"))
        batch_op.add_column(sa.Column("is_platform_user", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.create_foreign_key("fk_users_organization_id_organizations", "organizations", ["organization_id"], ["id"])
        batch_op.create_foreign_key("fk_users_created_by_user_id_users", "users", ["created_by_user_id"], ["id"])

    op.create_index("ix_users_organization_id", "users", ["organization_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_users_organization_id", table_name="users")
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_constraint("fk_users_created_by_user_id_users", type_="foreignkey")
        batch_op.drop_constraint("fk_users_organization_id_organizations", type_="foreignkey")
        batch_op.drop_column("is_platform_user")
        batch_op.drop_column("scope_level")
        batch_op.drop_column("created_by_user_id")
        batch_op.drop_column("organization_id")

    op.drop_index("ix_stations_setup_status", table_name="stations")
    with op.batch_alter_table("stations") as batch_op:
        batch_op.drop_column("created_at")
        batch_op.drop_column("allow_meter_adjustments")
        batch_op.drop_column("has_hardware")
        batch_op.drop_column("has_tankers")
        batch_op.drop_column("has_pos")
        batch_op.drop_column("has_shops")
        batch_op.drop_column("setup_completed_at")
        batch_op.drop_column("setup_status")
        batch_op.drop_column("is_active")
        batch_op.drop_column("use_organization_branding")
        batch_op.drop_column("logo_url")
        batch_op.drop_column("legal_name_override")
        batch_op.drop_column("display_name")

    op.drop_index("ix_organizations_billing_status", table_name="organizations")
    op.drop_index("ix_organizations_onboarding_status", table_name="organizations")
    op.drop_index("ix_organizations_brand_code", table_name="organizations")
    op.drop_index("ix_organizations_brand_name", table_name="organizations")
    with op.batch_alter_table("organizations") as batch_op:
        batch_op.drop_column("inherit_branding_to_stations")
        batch_op.drop_column("station_target_count")
        batch_op.drop_column("billing_status")
        batch_op.drop_column("onboarding_status")
        batch_op.drop_column("tax_registration_number")
        batch_op.drop_column("registration_number")
        batch_op.drop_column("contact_phone")
        batch_op.drop_column("contact_email")
        batch_op.drop_column("logo_url")
        batch_op.drop_column("brand_code")
        batch_op.drop_column("brand_name")
        batch_op.drop_column("legal_name")
