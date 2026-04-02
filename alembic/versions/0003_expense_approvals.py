"""add expense approval workflow

Revision ID: 0003_expense_approvals
Revises: 0002_organizations
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0003_expense_approvals"
down_revision = "0002_organizations"
branch_labels = None
depends_on = None


def _has_column(inspector, table_name: str, column_name: str) -> bool:
    return any(column["name"] == column_name for column in inspector.get_columns(table_name))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not _has_column(inspector, "expenses", "status"):
        op.add_column("expenses", sa.Column("status", sa.String(), nullable=True))
    if not _has_column(inspector, "expenses", "submitted_by_user_id"):
        op.add_column("expenses", sa.Column("submitted_by_user_id", sa.Integer(), nullable=True))
    if not _has_column(inspector, "expenses", "approved_by_user_id"):
        op.add_column("expenses", sa.Column("approved_by_user_id", sa.Integer(), nullable=True))
    if not _has_column(inspector, "expenses", "approved_at"):
        op.add_column("expenses", sa.Column("approved_at", sa.DateTime(), nullable=True))
    if not _has_column(inspector, "expenses", "rejected_at"):
        op.add_column("expenses", sa.Column("rejected_at", sa.DateTime(), nullable=True))
    if not _has_column(inspector, "expenses", "rejection_reason"):
        op.add_column("expenses", sa.Column("rejection_reason", sa.String(), nullable=True))

    op.execute("UPDATE expenses SET status = 'approved' WHERE status IS NULL")
    with op.batch_alter_table("expenses") as batch_op:
        batch_op.alter_column("status", existing_type=sa.String(), nullable=False)

    inspector = sa.inspect(bind)
    index_names = {index["name"] for index in inspector.get_indexes("expenses")}
    if "ix_expenses_status" not in index_names:
        op.create_index("ix_expenses_status", "expenses", ["status"], unique=False)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    index_names = {index["name"] for index in inspector.get_indexes("expenses")}
    if "ix_expenses_status" in index_names:
        op.drop_index("ix_expenses_status", table_name="expenses")

    for column_name in [
        "rejection_reason",
        "rejected_at",
        "approved_at",
        "approved_by_user_id",
        "submitted_by_user_id",
        "status",
    ]:
        if _has_column(sa.inspect(bind), "expenses", column_name):
            op.drop_column("expenses", column_name)
