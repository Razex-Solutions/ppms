"""document templates

Revision ID: 0014_document_templates
Revises: 0013_invoice_tax_and_sale_invoices
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0014_document_templates"
down_revision = "0013_invoice_tax_and_sale_invoices"
branch_labels = None
depends_on = None


def upgrade() -> None:
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
    op.create_index("ix_document_templates_station_id", "document_templates", ["station_id"], unique=False)
    op.create_index("ix_document_templates_document_type", "document_templates", ["document_type"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_document_templates_document_type", table_name="document_templates")
    op.drop_index("ix_document_templates_station_id", table_name="document_templates")
    op.drop_table("document_templates")
