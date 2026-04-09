"""customer credit issues

Revision ID: 0030_customer_credit_issues
Revises: 0029_tanker_org_ledger
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0030_customer_credit_issues"
down_revision = "0029_tanker_org_ledger"
branch_labels = None
depends_on = None


def _indexes(table_name: str) -> set[str]:
    return {index["name"] for index in inspect(op.get_bind()).get_indexes(table_name)}


def upgrade() -> None:
    bind = op.get_bind()
    if "customer_credit_issues" not in inspect(bind).get_table_names():
        op.create_table(
            "customer_credit_issues",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("customer_id", sa.Integer(), sa.ForeignKey("customers.id"), nullable=False),
            sa.Column("station_id", sa.Integer(), sa.ForeignKey("stations.id"), nullable=False),
            sa.Column("shift_id", sa.Integer(), sa.ForeignKey("shifts.id"), nullable=True),
            sa.Column("amount", sa.Float(), nullable=False),
            sa.Column("notes", sa.String(), nullable=True),
            sa.Column("created_by_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        )
    if "ix_customer_credit_issues_customer_id" not in _indexes("customer_credit_issues"):
        op.create_index("ix_customer_credit_issues_customer_id", "customer_credit_issues", ["customer_id"], unique=False)
    if "ix_customer_credit_issues_station_id" not in _indexes("customer_credit_issues"):
        op.create_index("ix_customer_credit_issues_station_id", "customer_credit_issues", ["station_id"], unique=False)
    if "ix_customer_credit_issues_shift_id" not in _indexes("customer_credit_issues"):
        op.create_index("ix_customer_credit_issues_shift_id", "customer_credit_issues", ["shift_id"], unique=False)
    if "ix_customer_credit_issues_created_by_user_id" not in _indexes("customer_credit_issues"):
        op.create_index("ix_customer_credit_issues_created_by_user_id", "customer_credit_issues", ["created_by_user_id"], unique=False)
    if "ix_customer_credit_issues_created_at" not in _indexes("customer_credit_issues"):
        op.create_index("ix_customer_credit_issues_created_at", "customer_credit_issues", ["created_at"], unique=False)


def downgrade() -> None:
    if "customer_credit_issues" in inspect(op.get_bind()).get_table_names():
        for index_name in [
            "ix_customer_credit_issues_created_at",
            "ix_customer_credit_issues_created_by_user_id",
            "ix_customer_credit_issues_shift_id",
            "ix_customer_credit_issues_station_id",
            "ix_customer_credit_issues_customer_id",
        ]:
            if index_name in _indexes("customer_credit_issues"):
                op.drop_index(index_name, table_name="customer_credit_issues")
        op.drop_table("customer_credit_issues")
