"""brand catalog and branding inheritance

Revision ID: 0024_brand_catalog_and_branding_inheritance
Revises: 0023_employee_profiles
Create Date: 2026-04-04
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0024_brand_catalog_and_branding_inheritance"
down_revision = "0023_employee_profiles"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)

    if "brand_catalog" not in inspector.get_table_names():
        op.create_table(
            "brand_catalog",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("code", sa.String(), nullable=False),
            sa.Column("name", sa.String(), nullable=False),
            sa.Column("logo_url", sa.String(), nullable=True),
            sa.Column("primary_color", sa.String(), nullable=True),
            sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        )
        op.create_index("ix_brand_catalog_id", "brand_catalog", ["id"], unique=False)
        op.create_index("ix_brand_catalog_code", "brand_catalog", ["code"], unique=True)
        op.create_index("ix_brand_catalog_name", "brand_catalog", ["name"], unique=True)

    organization_columns = {column["name"] for column in inspector.get_columns("organizations")}
    if "brand_catalog_id" not in organization_columns:
        with op.batch_alter_table("organizations") as batch_op:
            batch_op.add_column(sa.Column("brand_catalog_id", sa.Integer(), nullable=True))
            batch_op.create_index("ix_organizations_brand_catalog_id", ["brand_catalog_id"], unique=False)
            batch_op.create_foreign_key(
                "fk_organizations_brand_catalog_id",
                "brand_catalog",
                ["brand_catalog_id"],
                ["id"],
            )

    station_columns = {column["name"] for column in inspector.get_columns("stations")}
    with op.batch_alter_table("stations") as batch_op:
        if "brand_name" not in station_columns:
            batch_op.add_column(sa.Column("brand_name", sa.String(), nullable=True))
        if "brand_code" not in station_columns:
            batch_op.add_column(sa.Column("brand_code", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("stations", "brand_code")
    op.drop_column("stations", "brand_name")

    op.drop_constraint("fk_organizations_brand_catalog_id", "organizations", type_="foreignkey")
    op.drop_index("ix_organizations_brand_catalog_id", table_name="organizations")
    op.drop_column("organizations", "brand_catalog_id")

    op.drop_index("ix_brand_catalog_name", table_name="brand_catalog")
    op.drop_index("ix_brand_catalog_code", table_name="brand_catalog")
    op.drop_index("ix_brand_catalog_id", table_name="brand_catalog")
    op.drop_table("brand_catalog")
