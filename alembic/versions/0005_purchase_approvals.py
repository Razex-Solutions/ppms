"""add purchase approval workflow

Revision ID: 0005_purchase_approvals
Revises: 0004_reversal_approvals
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0005_purchase_approvals"
down_revision = "0004_reversal_approvals"
branch_labels = None
depends_on = None


def _has_column(inspector, table_name: str, column_name: str) -> bool:
    return any(column["name"] == column_name for column in inspector.get_columns(table_name))


def _has_index(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not _has_column(inspector, "purchases", "status"):
        op.add_column("purchases", sa.Column("status", sa.String(), nullable=True))
    if not _has_column(inspector, "purchases", "submitted_by_user_id"):
        op.add_column("purchases", sa.Column("submitted_by_user_id", sa.Integer(), nullable=True))
    if not _has_column(inspector, "purchases", "approved_by_user_id"):
        op.add_column("purchases", sa.Column("approved_by_user_id", sa.Integer(), nullable=True))
    if not _has_column(inspector, "purchases", "approved_at"):
        op.add_column("purchases", sa.Column("approved_at", sa.DateTime(), nullable=True))
    if not _has_column(inspector, "purchases", "rejected_at"):
        op.add_column("purchases", sa.Column("rejected_at", sa.DateTime(), nullable=True))
    if not _has_column(inspector, "purchases", "rejection_reason"):
        op.add_column("purchases", sa.Column("rejection_reason", sa.String(), nullable=True))

    op.execute("UPDATE purchases SET status = 'approved' WHERE status IS NULL")
    with op.batch_alter_table("purchases") as batch_op:
        batch_op.alter_column("status", existing_type=sa.String(), nullable=False)

    inspector = sa.inspect(bind)
    if not _has_index(inspector, "purchases", "ix_purchases_status"):
        op.create_index("ix_purchases_status", "purchases", ["status"], unique=False)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if _has_index(inspector, "purchases", "ix_purchases_status"):
        op.drop_index("ix_purchases_status", table_name="purchases")

    for column_name in [
        "rejection_reason",
        "rejected_at",
        "approved_at",
        "approved_by_user_id",
        "submitted_by_user_id",
        "status",
    ]:
        if _has_column(sa.inspect(bind), "purchases", column_name):
            op.drop_column("purchases", column_name)
