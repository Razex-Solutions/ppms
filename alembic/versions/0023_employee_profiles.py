"""employee profiles

Revision ID: 0023_employee_profiles
Revises: 0022_platform_foundation_and_station_setup
Create Date: 2026-04-04
"""

from alembic import op
import sqlalchemy as sa


revision = "0023_employee_profiles"
down_revision = "0022_platform_foundation_and_station_setup"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "employee_profiles",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("organization_id", sa.Integer(), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("station_id", sa.Integer(), sa.ForeignKey("stations.id"), nullable=False),
        sa.Column("linked_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True, unique=True),
        sa.Column("full_name", sa.String(), nullable=False),
        sa.Column("staff_type", sa.String(), nullable=False),
        sa.Column("employee_code", sa.String(), nullable=True),
        sa.Column("phone", sa.String(), nullable=True),
        sa.Column("national_id", sa.String(), nullable=True),
        sa.Column("address", sa.String(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("payroll_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("monthly_salary", sa.Float(), nullable=False, server_default="0"),
        sa.Column("can_login", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_employee_profiles_id", "employee_profiles", ["id"], unique=False)
    op.create_index("ix_employee_profiles_organization_id", "employee_profiles", ["organization_id"], unique=False)
    op.create_index("ix_employee_profiles_station_id", "employee_profiles", ["station_id"], unique=False)
    op.create_index("ix_employee_profiles_linked_user_id", "employee_profiles", ["linked_user_id"], unique=True)
    op.create_index("ix_employee_profiles_full_name", "employee_profiles", ["full_name"], unique=False)
    op.create_index("ix_employee_profiles_staff_type", "employee_profiles", ["staff_type"], unique=False)
    op.create_index("ix_employee_profiles_employee_code", "employee_profiles", ["employee_code"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_employee_profiles_employee_code", table_name="employee_profiles")
    op.drop_index("ix_employee_profiles_staff_type", table_name="employee_profiles")
    op.drop_index("ix_employee_profiles_full_name", table_name="employee_profiles")
    op.drop_index("ix_employee_profiles_linked_user_id", table_name="employee_profiles")
    op.drop_index("ix_employee_profiles_station_id", table_name="employee_profiles")
    op.drop_index("ix_employee_profiles_organization_id", table_name="employee_profiles")
    op.drop_index("ix_employee_profiles_id", table_name="employee_profiles")
    op.drop_table("employee_profiles")
