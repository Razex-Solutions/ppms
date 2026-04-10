"""add buying price to pos products

Revision ID: 0032_pos_product_buying_price
Revises: 0031_credit_issue_sale_context
Create Date: 2026-04-10
"""

from alembic import op
import sqlalchemy as sa


revision = "0032_pos_product_buying_price"
down_revision = "0031_credit_issue_sale_context"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_columns = {
        column["name"] for column in inspector.get_columns("pos_products")
    }
    if "buying_price" not in existing_columns:
        op.add_column(
            "pos_products",
            sa.Column(
                "buying_price",
                sa.Float(),
                nullable=False,
                server_default="0",
            ),
        )


def downgrade() -> None:
    op.drop_column("pos_products", "buying_price")
