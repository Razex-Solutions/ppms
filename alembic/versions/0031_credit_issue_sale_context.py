"""credit issue sale context

Revision ID: 0031_credit_issue_sale_context
Revises: 0030_customer_credit_issues
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0031_credit_issue_sale_context"
down_revision = "0030_customer_credit_issues"
branch_labels = None
depends_on = None


def _columns(table_name: str) -> set[str]:
    return {column["name"] for column in inspect(op.get_bind()).get_columns(table_name)}


def _indexes(table_name: str) -> set[str]:
    return {index["name"] for index in inspect(op.get_bind()).get_indexes(table_name)}


def upgrade() -> None:
    if "nozzle_id" not in _columns("customer_credit_issues"):
        op.add_column("customer_credit_issues", sa.Column("nozzle_id", sa.Integer(), nullable=True))
    if "tank_id" not in _columns("customer_credit_issues"):
        op.add_column("customer_credit_issues", sa.Column("tank_id", sa.Integer(), nullable=True))
    if "fuel_type_id" not in _columns("customer_credit_issues"):
        op.add_column("customer_credit_issues", sa.Column("fuel_type_id", sa.Integer(), nullable=True))
    if "quantity" not in _columns("customer_credit_issues"):
        op.add_column("customer_credit_issues", sa.Column("quantity", sa.Float(), nullable=True))
    if "rate_per_liter" not in _columns("customer_credit_issues"):
        op.add_column("customer_credit_issues", sa.Column("rate_per_liter", sa.Float(), nullable=True))

    index_specs = [
        ("ix_customer_credit_issues_nozzle_id", ["nozzle_id"]),
        ("ix_customer_credit_issues_tank_id", ["tank_id"]),
        ("ix_customer_credit_issues_fuel_type_id", ["fuel_type_id"]),
    ]
    for index_name, columns in index_specs:
        if index_name not in _indexes("customer_credit_issues"):
            op.create_index(index_name, "customer_credit_issues", columns, unique=False)


def downgrade() -> None:
    for index_name in [
        "ix_customer_credit_issues_fuel_type_id",
        "ix_customer_credit_issues_tank_id",
        "ix_customer_credit_issues_nozzle_id",
    ]:
        if index_name in _indexes("customer_credit_issues"):
            op.drop_index(index_name, table_name="customer_credit_issues")

    for column_name in ["rate_per_liter", "quantity", "fuel_type_id", "tank_id", "nozzle_id"]:
        if column_name in _columns("customer_credit_issues"):
            op.drop_column("customer_credit_issues", column_name)
