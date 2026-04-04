"""invoice tax and sale invoices

Revision ID: 0013_invoice_tax_and_sale_invoices
Revises: 0012_delivery_retry_state
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0013_invoice_tax_and_sale_invoices"
down_revision = "0012_delivery_retry_state"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = inspect(op.get_bind())
    columns = {column["name"] for column in inspector.get_columns("invoice_profiles")}
    additions = [
        ("legal_name", sa.Column("legal_name", sa.String(), nullable=True)),
        ("registration_no", sa.Column("registration_no", sa.String(), nullable=True)),
        ("tax_registration_no", sa.Column("tax_registration_no", sa.String(), nullable=True)),
        ("default_tax_rate", sa.Column("default_tax_rate", sa.Float(), nullable=False, server_default="0")),
        ("tax_inclusive", sa.Column("tax_inclusive", sa.Boolean(), nullable=False, server_default=sa.false())),
        ("invoice_series", sa.Column("invoice_series", sa.String(), nullable=True)),
        ("invoice_number_width", sa.Column("invoice_number_width", sa.Integer(), nullable=False, server_default="6")),
        ("payment_terms", sa.Column("payment_terms", sa.Text(), nullable=True)),
        ("sale_invoice_notes", sa.Column("sale_invoice_notes", sa.Text(), nullable=True)),
    ]
    for name, column in additions:
        if name not in columns:
            op.add_column("invoice_profiles", column)


def downgrade() -> None:
    with op.batch_alter_table("invoice_profiles") as batch_op:
        batch_op.drop_column("sale_invoice_notes")
        batch_op.drop_column("payment_terms")
        batch_op.drop_column("invoice_number_width")
        batch_op.drop_column("invoice_series")
        batch_op.drop_column("tax_inclusive")
        batch_op.drop_column("default_tax_rate")
        batch_op.drop_column("tax_registration_no")
        batch_op.drop_column("registration_no")
        batch_op.drop_column("legal_name")
