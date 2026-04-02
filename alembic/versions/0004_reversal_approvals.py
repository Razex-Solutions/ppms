"""add reversal approval metadata

Revision ID: 0004_reversal_approvals
Revises: 0003_expense_approvals
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0004_reversal_approvals"
down_revision = "0003_expense_approvals"
branch_labels = None
depends_on = None


TABLES = [
    "fuel_sales",
    "purchases",
    "customer_payments",
    "supplier_payments",
]


def _has_column(inspector, table_name: str, column_name: str) -> bool:
    return any(column["name"] == column_name for column in inspector.get_columns(table_name))


def _has_index(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    for table_name in TABLES:
        if not _has_column(inspector, table_name, "reversal_request_status"):
            op.add_column(table_name, sa.Column("reversal_request_status", sa.String(), nullable=True))
        if not _has_column(inspector, table_name, "reversal_requested_at"):
            op.add_column(table_name, sa.Column("reversal_requested_at", sa.DateTime(), nullable=True))
        if not _has_column(inspector, table_name, "reversal_requested_by"):
            op.add_column(table_name, sa.Column("reversal_requested_by", sa.Integer(), nullable=True))
        if not _has_column(inspector, table_name, "reversal_request_reason"):
            op.add_column(table_name, sa.Column("reversal_request_reason", sa.String(), nullable=True))
        if not _has_column(inspector, table_name, "reversal_reviewed_at"):
            op.add_column(table_name, sa.Column("reversal_reviewed_at", sa.DateTime(), nullable=True))
        if not _has_column(inspector, table_name, "reversal_reviewed_by"):
            op.add_column(table_name, sa.Column("reversal_reviewed_by", sa.Integer(), nullable=True))
        if not _has_column(inspector, table_name, "reversal_rejection_reason"):
            op.add_column(table_name, sa.Column("reversal_rejection_reason", sa.String(), nullable=True))
        inspector = sa.inspect(bind)
        index_name = f"ix_{table_name}_reversal_request_status"
        if not _has_index(inspector, table_name, index_name):
            op.create_index(index_name, table_name, ["reversal_request_status"], unique=False)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    for table_name in TABLES:
        index_name = f"ix_{table_name}_reversal_request_status"
        if _has_index(inspector, table_name, index_name):
            op.drop_index(index_name, table_name=table_name)
        for column_name in [
            "reversal_rejection_reason",
            "reversal_reviewed_by",
            "reversal_reviewed_at",
            "reversal_request_reason",
            "reversal_requested_by",
            "reversal_requested_at",
            "reversal_request_status",
        ]:
            if _has_column(sa.inspect(bind), table_name, column_name):
                op.drop_column(table_name, column_name)
