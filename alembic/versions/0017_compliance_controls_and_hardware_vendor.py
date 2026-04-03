"""compliance controls and hardware vendor fields

Revision ID: 0017_compliance_controls_and_hardware_vendor
Revises: 0016_online_api_hooks
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0017_compliance_controls_and_hardware_vendor"
down_revision = "0016_online_api_hooks"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("invoice_profiles") as batch_op:
        batch_op.add_column(sa.Column("region_code", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("currency_code", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("compliance_mode", sa.String(), nullable=False, server_default="standard"))
        batch_op.add_column(
            sa.Column("enforce_tax_registration", sa.Boolean(), nullable=False, server_default=sa.false())
        )

    with op.batch_alter_table("hardware_devices") as batch_op:
        batch_op.add_column(sa.Column("vendor_name", sa.String(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("hardware_devices") as batch_op:
        batch_op.drop_column("vendor_name")

    with op.batch_alter_table("invoice_profiles") as batch_op:
        batch_op.drop_column("enforce_tax_registration")
        batch_op.drop_column("compliance_mode")
        batch_op.drop_column("currency_code")
        batch_op.drop_column("region_code")
