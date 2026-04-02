"""invoice tax and sale invoices

Revision ID: 0013_invoice_tax_and_sale_invoices
Revises: 0012_delivery_retry_state
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0013_invoice_tax_and_sale_invoices"
down_revision = "0012_delivery_retry_state"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("invoice_profiles") as batch_op:
        batch_op.add_column(sa.Column("legal_name", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("registration_no", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("tax_registration_no", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("default_tax_rate", sa.Float(), nullable=False, server_default="0"))
        batch_op.add_column(sa.Column("tax_inclusive", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column("invoice_series", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("invoice_number_width", sa.Integer(), nullable=False, server_default="6"))
        batch_op.add_column(sa.Column("payment_terms", sa.Text(), nullable=True))
        batch_op.add_column(sa.Column("sale_invoice_notes", sa.Text(), nullable=True))


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
