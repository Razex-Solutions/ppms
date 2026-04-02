"""add tanker operations module

Revision ID: 0008_tanker_operations_module
Revises: 0007_report_export_jobs
Create Date: 2026-04-03
"""

from alembic import op
import sqlalchemy as sa


revision = "0008_tanker_operations_module"
down_revision = "0007_report_export_jobs"
branch_labels = None
depends_on = None


def _has_column(inspector, table_name: str, column_name: str) -> bool:
    return any(column["name"] == column_name for column in inspector.get_columns(table_name))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if "station_module_settings" not in inspector.get_table_names():
        op.create_table(
            "station_module_settings",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("station_id", sa.Integer(), nullable=False),
            sa.Column("module_name", sa.String(), nullable=False),
            sa.Column("is_enabled", sa.Boolean(), nullable=False, server_default=sa.text("0")),
            sa.ForeignKeyConstraint(["station_id"], ["stations.id"]),
        )
        op.create_index("ix_station_module_settings_station_id", "station_module_settings", ["station_id"], unique=False)
        op.create_index("ix_station_module_settings_module_name", "station_module_settings", ["module_name"], unique=False)

    if not _has_column(inspector, "tankers", "ownership_type"):
        op.add_column("tankers", sa.Column("ownership_type", sa.String(), nullable=True))
        op.execute("UPDATE tankers SET ownership_type = 'owned' WHERE ownership_type IS NULL")

    if "tanker_trips" not in inspector.get_table_names():
        op.create_table(
            "tanker_trips",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("tanker_id", sa.Integer(), nullable=False),
            sa.Column("station_id", sa.Integer(), nullable=False),
            sa.Column("supplier_id", sa.Integer(), nullable=True),
            sa.Column("fuel_type_id", sa.Integer(), nullable=False),
            sa.Column("trip_type", sa.String(), nullable=False),
            sa.Column("status", sa.String(), nullable=False),
            sa.Column("settlement_status", sa.String(), nullable=False),
            sa.Column("linked_tank_id", sa.Integer(), nullable=True),
            sa.Column("linked_purchase_id", sa.Integer(), nullable=True),
            sa.Column("destination_name", sa.String(), nullable=True),
            sa.Column("notes", sa.String(), nullable=True),
            sa.Column("total_quantity", sa.Float(), nullable=False, server_default="0"),
            sa.Column("fuel_revenue", sa.Float(), nullable=False, server_default="0"),
            sa.Column("delivery_revenue", sa.Float(), nullable=False, server_default="0"),
            sa.Column("expense_total", sa.Float(), nullable=False, server_default="0"),
            sa.Column("net_profit", sa.Float(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("completed_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["tanker_id"], ["tankers.id"]),
            sa.ForeignKeyConstraint(["station_id"], ["stations.id"]),
            sa.ForeignKeyConstraint(["supplier_id"], ["suppliers.id"]),
            sa.ForeignKeyConstraint(["fuel_type_id"], ["fuel_types.id"]),
            sa.ForeignKeyConstraint(["linked_tank_id"], ["tanks.id"]),
            sa.ForeignKeyConstraint(["linked_purchase_id"], ["purchases.id"]),
        )
        for index_name, column_name in [
            ("ix_tanker_trips_tanker_id", "tanker_id"),
            ("ix_tanker_trips_station_id", "station_id"),
            ("ix_tanker_trips_supplier_id", "supplier_id"),
            ("ix_tanker_trips_fuel_type_id", "fuel_type_id"),
            ("ix_tanker_trips_trip_type", "trip_type"),
            ("ix_tanker_trips_status", "status"),
            ("ix_tanker_trips_settlement_status", "settlement_status"),
            ("ix_tanker_trips_linked_tank_id", "linked_tank_id"),
            ("ix_tanker_trips_linked_purchase_id", "linked_purchase_id"),
        ]:
            op.create_index(index_name, "tanker_trips", [column_name], unique=False)

    if "tanker_deliveries" not in inspector.get_table_names():
        op.create_table(
            "tanker_deliveries",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("trip_id", sa.Integer(), nullable=False),
            sa.Column("customer_id", sa.Integer(), nullable=True),
            sa.Column("destination_name", sa.String(), nullable=True),
            sa.Column("quantity", sa.Float(), nullable=False),
            sa.Column("fuel_rate", sa.Float(), nullable=False),
            sa.Column("fuel_amount", sa.Float(), nullable=False),
            sa.Column("delivery_charge", sa.Float(), nullable=False, server_default="0"),
            sa.Column("sale_type", sa.String(), nullable=False),
            sa.Column("paid_amount", sa.Float(), nullable=False, server_default="0"),
            sa.Column("outstanding_amount", sa.Float(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["trip_id"], ["tanker_trips.id"]),
            sa.ForeignKeyConstraint(["customer_id"], ["customers.id"]),
        )
        op.create_index("ix_tanker_deliveries_trip_id", "tanker_deliveries", ["trip_id"], unique=False)
        op.create_index("ix_tanker_deliveries_customer_id", "tanker_deliveries", ["customer_id"], unique=False)

    if "tanker_trip_expenses" not in inspector.get_table_names():
        op.create_table(
            "tanker_trip_expenses",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("trip_id", sa.Integer(), nullable=False),
            sa.Column("expense_type", sa.String(), nullable=False),
            sa.Column("amount", sa.Float(), nullable=False),
            sa.Column("notes", sa.String(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["trip_id"], ["tanker_trips.id"]),
        )
        op.create_index("ix_tanker_trip_expenses_trip_id", "tanker_trip_expenses", ["trip_id"], unique=False)
        op.create_index("ix_tanker_trip_expenses_expense_type", "tanker_trip_expenses", ["expense_type"], unique=False)


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if "tanker_trip_expenses" in inspector.get_table_names():
        op.drop_index("ix_tanker_trip_expenses_expense_type", table_name="tanker_trip_expenses")
        op.drop_index("ix_tanker_trip_expenses_trip_id", table_name="tanker_trip_expenses")
        op.drop_table("tanker_trip_expenses")
    inspector = sa.inspect(op.get_bind())
    if "tanker_deliveries" in inspector.get_table_names():
        op.drop_index("ix_tanker_deliveries_customer_id", table_name="tanker_deliveries")
        op.drop_index("ix_tanker_deliveries_trip_id", table_name="tanker_deliveries")
        op.drop_table("tanker_deliveries")
    inspector = sa.inspect(op.get_bind())
    if "tanker_trips" in inspector.get_table_names():
        for index_name in [
            "ix_tanker_trips_linked_purchase_id",
            "ix_tanker_trips_linked_tank_id",
            "ix_tanker_trips_settlement_status",
            "ix_tanker_trips_status",
            "ix_tanker_trips_trip_type",
            "ix_tanker_trips_fuel_type_id",
            "ix_tanker_trips_supplier_id",
            "ix_tanker_trips_station_id",
            "ix_tanker_trips_tanker_id",
        ]:
            op.drop_index(index_name, table_name="tanker_trips")
        op.drop_table("tanker_trips")
    inspector = sa.inspect(op.get_bind())
    if _has_column(inspector, "tankers", "ownership_type"):
        op.drop_column("tankers", "ownership_type")
    if "station_module_settings" in inspector.get_table_names():
        op.drop_index("ix_station_module_settings_module_name", table_name="station_module_settings")
        op.drop_index("ix_station_module_settings_station_id", table_name="station_module_settings")
        op.drop_table("station_module_settings")
