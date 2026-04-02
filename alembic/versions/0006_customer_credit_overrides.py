"""add customer credit override workflow

Revision ID: 0006_customer_credit_overrides
Revises: 0005_purchase_approvals
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0006_customer_credit_overrides"
down_revision = "0005_purchase_approvals"
branch_labels = None
depends_on = None


def _has_column(inspector, table_name: str, column_name: str) -> bool:
    return any(column["name"] == column_name for column in inspector.get_columns(table_name))


def _has_index(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    for column_name, column in [
        ("credit_override_status", sa.Column("credit_override_status", sa.String(), nullable=True)),
        ("credit_override_amount", sa.Column("credit_override_amount", sa.Float(), nullable=True)),
        ("credit_override_requested_amount", sa.Column("credit_override_requested_amount", sa.Float(), nullable=True)),
        ("credit_override_requested_at", sa.Column("credit_override_requested_at", sa.DateTime(), nullable=True)),
        ("credit_override_requested_by", sa.Column("credit_override_requested_by", sa.Integer(), nullable=True)),
        ("credit_override_reason", sa.Column("credit_override_reason", sa.String(), nullable=True)),
        ("credit_override_reviewed_at", sa.Column("credit_override_reviewed_at", sa.DateTime(), nullable=True)),
        ("credit_override_reviewed_by", sa.Column("credit_override_reviewed_by", sa.Integer(), nullable=True)),
        ("credit_override_rejection_reason", sa.Column("credit_override_rejection_reason", sa.String(), nullable=True)),
    ]:
        if not _has_column(inspector, "customers", column_name):
            op.add_column("customers", column)

    op.execute("UPDATE customers SET credit_override_amount = 0 WHERE credit_override_amount IS NULL")
    op.execute("UPDATE customers SET credit_override_requested_amount = 0 WHERE credit_override_requested_amount IS NULL")

    inspector = sa.inspect(bind)
    if not _has_index(inspector, "customers", "ix_customers_credit_override_status"):
        op.create_index("ix_customers_credit_override_status", "customers", ["credit_override_status"], unique=False)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if _has_index(inspector, "customers", "ix_customers_credit_override_status"):
        op.drop_index("ix_customers_credit_override_status", table_name="customers")

    for column_name in [
        "credit_override_rejection_reason",
        "credit_override_reviewed_by",
        "credit_override_reviewed_at",
        "credit_override_reason",
        "credit_override_requested_by",
        "credit_override_requested_at",
        "credit_override_requested_amount",
        "credit_override_amount",
        "credit_override_status",
    ]:
        if _has_column(sa.inspect(bind), "customers", column_name):
            op.drop_column("customers", column_name)
