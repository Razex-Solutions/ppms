"""tanker org compartments and ledgers

Revision ID: 0029_tanker_org_ledger
Revises: 0028_staff_titles_forecourt
Create Date: 2026-04-09
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0029_tanker_org_ledger"
down_revision = "0028_staff_titles_forecourt"
branch_labels = None
depends_on = None


def _columns(table_name: str) -> set[str]:
    return {column["name"] for column in inspect(op.get_bind()).get_columns(table_name)}


def _indexes(table_name: str) -> set[str]:
    return {index["name"] for index in inspect(op.get_bind()).get_indexes(table_name)}


def _ensure_column(table_name: str, column: sa.Column) -> None:
    if column.name not in _columns(table_name):
        op.add_column(table_name, column)


def _ensure_index(table_name: str, index_name: str, columns: list[str]) -> None:
    if index_name not in _indexes(table_name):
        op.create_index(index_name, table_name, columns, unique=False)


def upgrade() -> None:
    _ensure_column("customers", sa.Column("tanker_outstanding_balance", sa.Float(), nullable=False, server_default="0"))

    _ensure_column("tankers", sa.Column("organization_id", sa.Integer(), nullable=True))
    _ensure_index("tankers", "ix_tankers_organization_id", ["organization_id"])

    _ensure_column("tanker_trips", sa.Column("organization_id", sa.Integer(), nullable=True))
    _ensure_index("tanker_trips", "ix_tanker_trips_organization_id", ["organization_id"])

    bind = op.get_bind()
    if "tanker_trip_compartment_loads" not in inspect(bind).get_table_names():
        op.create_table(
            "tanker_trip_compartment_loads",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("trip_id", sa.Integer(), sa.ForeignKey("tanker_trips.id"), nullable=False),
            sa.Column("compartment_id", sa.Integer(), sa.ForeignKey("tanker_compartments.id"), nullable=False),
            sa.Column("fuel_type_id", sa.Integer(), sa.ForeignKey("fuel_types.id"), nullable=False),
            sa.Column("loaded_quantity", sa.Float(), nullable=False),
            sa.Column("remaining_quantity", sa.Float(), nullable=False),
            sa.Column("purchase_rate", sa.Float(), nullable=False),
            sa.Column("purchase_total", sa.Float(), nullable=False),
        )
    _ensure_index("tanker_trip_compartment_loads", "ix_tanker_trip_compartment_loads_trip_id", ["trip_id"])
    _ensure_index("tanker_trip_compartment_loads", "ix_tanker_trip_compartment_loads_compartment_id", ["compartment_id"])
    _ensure_index("tanker_trip_compartment_loads", "ix_tanker_trip_compartment_loads_fuel_type_id", ["fuel_type_id"])

    if "fuel_type_id" not in _columns("tanker_deliveries"):
        op.add_column("tanker_deliveries", sa.Column("fuel_type_id", sa.Integer(), nullable=True))
    if "compartment_load_id" not in _columns("tanker_deliveries"):
        op.add_column("tanker_deliveries", sa.Column("compartment_load_id", sa.Integer(), nullable=True))
    _ensure_index("tanker_deliveries", "ix_tanker_deliveries_fuel_type_id", ["fuel_type_id"])
    _ensure_index("tanker_deliveries", "ix_tanker_deliveries_compartment_load_id", ["compartment_load_id"])

    if "tanker_trip_driver_assignments" not in inspect(bind).get_table_names():
        op.create_table(
            "tanker_trip_driver_assignments",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("trip_id", sa.Integer(), sa.ForeignKey("tanker_trips.id"), nullable=False),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("assignment_role", sa.String(), nullable=False, server_default="driver"),
        )
    _ensure_index("tanker_trip_driver_assignments", "ix_tanker_trip_driver_assignments_trip_id", ["trip_id"])
    _ensure_index("tanker_trip_driver_assignments", "ix_tanker_trip_driver_assignments_user_id", ["user_id"])

    if "tanker_delivery_payments" not in inspect(bind).get_table_names():
        op.create_table(
            "tanker_delivery_payments",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("delivery_id", sa.Integer(), sa.ForeignKey("tanker_deliveries.id"), nullable=False),
            sa.Column("amount", sa.Float(), nullable=False),
            sa.Column("payment_method", sa.String(), nullable=True),
            sa.Column("reference_no", sa.String(), nullable=True),
            sa.Column("notes", sa.String(), nullable=True),
            sa.Column("received_by_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
            sa.Column("received_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        )
    _ensure_index("tanker_delivery_payments", "ix_tanker_delivery_payments_delivery_id", ["delivery_id"])
    _ensure_index("tanker_delivery_payments", "ix_tanker_delivery_payments_received_by_user_id", ["received_by_user_id"])

    op.execute(
        """
        UPDATE tankers
        SET organization_id = (
            SELECT stations.organization_id
            FROM stations
            WHERE stations.id = tankers.station_id
        )
        WHERE organization_id IS NULL
        """
    )
    op.execute(
        """
        UPDATE tanker_trips
        SET organization_id = (
            SELECT tankers.organization_id
            FROM tankers
            WHERE tankers.id = tanker_trips.tanker_id
        )
        WHERE organization_id IS NULL
        """
    )
    op.execute(
        """
        UPDATE tanker_deliveries
        SET fuel_type_id = (
            SELECT tanker_trips.fuel_type_id
            FROM tanker_trips
            WHERE tanker_trips.id = tanker_deliveries.trip_id
        )
        WHERE fuel_type_id IS NULL
        """
    )


def downgrade() -> None:
    if "ix_tanker_delivery_payments_received_by_user_id" in _indexes("tanker_delivery_payments"):
        op.drop_index("ix_tanker_delivery_payments_received_by_user_id", table_name="tanker_delivery_payments")
    if "ix_tanker_delivery_payments_delivery_id" in _indexes("tanker_delivery_payments"):
        op.drop_index("ix_tanker_delivery_payments_delivery_id", table_name="tanker_delivery_payments")
    if "tanker_delivery_payments" in inspect(op.get_bind()).get_table_names():
        op.drop_table("tanker_delivery_payments")

    if "ix_tanker_trip_driver_assignments_user_id" in _indexes("tanker_trip_driver_assignments"):
        op.drop_index("ix_tanker_trip_driver_assignments_user_id", table_name="tanker_trip_driver_assignments")
    if "ix_tanker_trip_driver_assignments_trip_id" in _indexes("tanker_trip_driver_assignments"):
        op.drop_index("ix_tanker_trip_driver_assignments_trip_id", table_name="tanker_trip_driver_assignments")
    if "tanker_trip_driver_assignments" in inspect(op.get_bind()).get_table_names():
        op.drop_table("tanker_trip_driver_assignments")

    if "ix_tanker_trip_compartment_loads_fuel_type_id" in _indexes("tanker_trip_compartment_loads"):
        op.drop_index("ix_tanker_trip_compartment_loads_fuel_type_id", table_name="tanker_trip_compartment_loads")
    if "ix_tanker_trip_compartment_loads_compartment_id" in _indexes("tanker_trip_compartment_loads"):
        op.drop_index("ix_tanker_trip_compartment_loads_compartment_id", table_name="tanker_trip_compartment_loads")
    if "ix_tanker_trip_compartment_loads_trip_id" in _indexes("tanker_trip_compartment_loads"):
        op.drop_index("ix_tanker_trip_compartment_loads_trip_id", table_name="tanker_trip_compartment_loads")
    if "tanker_trip_compartment_loads" in inspect(op.get_bind()).get_table_names():
        op.drop_table("tanker_trip_compartment_loads")

    if "ix_tanker_deliveries_compartment_load_id" in _indexes("tanker_deliveries"):
        op.drop_index("ix_tanker_deliveries_compartment_load_id", table_name="tanker_deliveries")
    if "ix_tanker_deliveries_fuel_type_id" in _indexes("tanker_deliveries"):
        op.drop_index("ix_tanker_deliveries_fuel_type_id", table_name="tanker_deliveries")
    if "compartment_load_id" in _columns("tanker_deliveries"):
        op.drop_column("tanker_deliveries", "compartment_load_id")
    if "fuel_type_id" in _columns("tanker_deliveries"):
        op.drop_column("tanker_deliveries", "fuel_type_id")

    if "ix_tanker_trips_organization_id" in _indexes("tanker_trips"):
        op.drop_index("ix_tanker_trips_organization_id", table_name="tanker_trips")
    if "organization_id" in _columns("tanker_trips"):
        op.drop_column("tanker_trips", "organization_id")

    if "ix_tankers_organization_id" in _indexes("tankers"):
        op.drop_index("ix_tankers_organization_id", table_name="tankers")
    if "organization_id" in _columns("tankers"):
        op.drop_column("tankers", "organization_id")

    if "tanker_outstanding_balance" in _columns("customers"):
        op.drop_column("customers", "tanker_outstanding_balance")
