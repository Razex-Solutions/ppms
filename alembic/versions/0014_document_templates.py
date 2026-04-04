"""document templates

Revision ID: 0014_document_templates
Revises: 0013_invoice_tax_and_sale_invoices
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0014_document_templates"
down_revision = "0013_invoice_tax_and_sale_invoices"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = inspect(op.get_bind())
    if "document_templates" not in inspector.get_table_names():
        op.create_table(
            "document_templates",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("station_id", sa.Integer(), sa.ForeignKey("stations.id"), nullable=False),
            sa.Column("document_type", sa.String(), nullable=False),
            sa.Column("name", sa.String(), nullable=False),
            sa.Column("header_html", sa.Text(), nullable=True),
            sa.Column("body_html", sa.Text(), nullable=True),
            sa.Column("footer_html", sa.Text(), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        )
    existing_indexes = {index["name"] for index in inspect(op.get_bind()).get_indexes("document_templates")}
    if "ix_document_templates_station_id" not in existing_indexes:
        op.create_index("ix_document_templates_station_id", "document_templates", ["station_id"], unique=False)
    if "ix_document_templates_document_type" not in existing_indexes:
        op.create_index("ix_document_templates_document_type", "document_templates", ["document_type"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_document_templates_document_type", table_name="document_templates")
    op.drop_index("ix_document_templates_station_id", table_name="document_templates")
    op.drop_table("document_templates")
