"""Add organizations and station ownership

Revision ID: 0002_organizations
Revises: 0001_initial_schema
Create Date: 2026-04-03 18:15:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect, text


revision = "0002_organizations"
down_revision = "0001_initial_schema"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)

    if not inspector.has_table("organizations"):
        op.create_table(
            "organizations",
            sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
            sa.Column("name", sa.String(), nullable=False),
            sa.Column("code", sa.String(), nullable=False),
            sa.Column("description", sa.String(), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        )
        op.create_index(op.f("ix_organizations_id"), "organizations", ["id"], unique=False)
        op.create_index(op.f("ix_organizations_name"), "organizations", ["name"], unique=False)
        op.create_index(op.f("ix_organizations_code"), "organizations", ["code"], unique=True)

    station_columns = {column["name"] for column in inspector.get_columns("stations")}
    if "organization_id" not in station_columns:
        op.add_column("stations", sa.Column("organization_id", sa.Integer(), nullable=True))
        op.create_index(op.f("ix_stations_organization_id"), "stations", ["organization_id"], unique=False)
    if "is_head_office" not in station_columns:
        op.add_column("stations", sa.Column("is_head_office", sa.Boolean(), nullable=False, server_default=sa.text("0")))

    default_org = bind.execute(text("SELECT id FROM organizations WHERE code = 'DEFAULT'")).scalar()
    if default_org is None:
        bind.execute(
            text(
                "INSERT INTO organizations (name, code, description, is_active) "
                "VALUES ('Default Organization', 'DEFAULT', 'Auto-created for existing stations', 1)"
            )
        )
        default_org = bind.execute(text("SELECT id FROM organizations WHERE code = 'DEFAULT'")).scalar()

    bind.execute(
        text("UPDATE stations SET organization_id = :organization_id WHERE organization_id IS NULL"),
        {"organization_id": default_org},
    )

    first_station_id = bind.execute(text("SELECT id FROM stations ORDER BY id ASC LIMIT 1")).scalar()
    if first_station_id is not None:
        bind.execute(text("UPDATE stations SET is_head_office = 1 WHERE id = :station_id"), {"station_id": first_station_id})


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    station_columns = {column["name"] for column in inspector.get_columns("stations")}

    if "is_head_office" in station_columns:
        op.drop_column("stations", "is_head_office")
    if "organization_id" in station_columns:
        op.drop_index(op.f("ix_stations_organization_id"), table_name="stations")
        op.drop_column("stations", "organization_id")

    if inspector.has_table("organizations"):
        op.drop_index(op.f("ix_organizations_code"), table_name="organizations")
        op.drop_index(op.f("ix_organizations_name"), table_name="organizations")
        op.drop_index(op.f("ix_organizations_id"), table_name="organizations")
        op.drop_table("organizations")
