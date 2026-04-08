"""shift nozzle snapshots

Revision ID: 0026_shift_nozzle_snapshots
Revises: 0025_profile_payroll_lines
Create Date: 2026-04-09
"""

from alembic import op
from sqlalchemy import inspect, text


revision = "0026_shift_nozzle_snapshots"
down_revision = "0025_profile_payroll_lines"
branch_labels = None
depends_on = None


def _tables() -> set[str]:
    return set(inspect(op.get_bind()).get_table_names())


def _columns(table_name: str) -> set[str]:
    return {column["name"] for column in inspect(op.get_bind()).get_columns(table_name)}


def _drop_leftovers() -> None:
    bind = op.get_bind()
    for table_name in _tables():
        if table_name.startswith("_alembic_tmp_") or table_name in {"nozzle_readings_new", "nozzle_readings_rebuild"}:
            bind.execute(text(f'DROP TABLE "{table_name}"'))


def _create_final_table(table_name: str) -> None:
    bind = op.get_bind()
    bind.execute(
        text(
            f"""
            CREATE TABLE {table_name} (
                id INTEGER NOT NULL PRIMARY KEY,
                nozzle_id INTEGER NOT NULL REFERENCES nozzles(id),
                reading FLOAT NOT NULL,
                sale_id INTEGER REFERENCES fuel_sales(id),
                shift_id INTEGER REFERENCES shifts(id),
                reading_type VARCHAR NOT NULL,
                created_at DATETIME
            )
            """
        )
    )


def _rebuild_from_existing_table() -> None:
    bind = op.get_bind()
    _create_final_table("nozzle_readings_rebuild")
    bind.execute(
        text(
            """
            INSERT INTO nozzle_readings_rebuild (
                id, nozzle_id, reading, sale_id, shift_id, reading_type, created_at
            )
            SELECT
                id, nozzle_id, reading, sale_id, NULL, 'sale', created_at
            FROM nozzle_readings
            """
        )
    )
    bind.execute(text("DROP TABLE nozzle_readings"))
    bind.execute(text("ALTER TABLE nozzle_readings_rebuild RENAME TO nozzle_readings"))


def _restore_from_fuel_sales() -> None:
    bind = op.get_bind()
    _create_final_table("nozzle_readings")
    bind.execute(
        text(
            """
            INSERT INTO nozzle_readings (
                id, nozzle_id, reading, sale_id, shift_id, reading_type, created_at
            )
            SELECT
                id, nozzle_id, closing_meter, id, shift_id, 'sale', created_at
            FROM fuel_sales
            """
        )
    )


def _ensure_indexes() -> None:
    bind = op.get_bind()
    index_names = {index["name"] for index in inspect(bind).get_indexes("nozzle_readings")}
    if "ix_nozzle_readings_id" not in index_names:
        bind.execute(text("CREATE INDEX ix_nozzle_readings_id ON nozzle_readings (id)"))
    if "ix_nozzle_readings_shift_id" not in index_names:
        bind.execute(text("CREATE INDEX ix_nozzle_readings_shift_id ON nozzle_readings (shift_id)"))
    if "ix_nozzle_readings_reading_type" not in index_names:
        bind.execute(text("CREATE INDEX ix_nozzle_readings_reading_type ON nozzle_readings (reading_type)"))


def upgrade() -> None:
    _drop_leftovers()
    tables = _tables()

    if "nozzle_readings" in tables:
        if {"shift_id", "reading_type"}.issubset(_columns("nozzle_readings")):
            _ensure_indexes()
            return
        _rebuild_from_existing_table()
    else:
        _restore_from_fuel_sales()

    _ensure_indexes()


def downgrade() -> None:
    # Forward-only local migration.
    pass
