from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker, declarative_base

from app.core.config import DATABASE_URL

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def ensure_sqlite_transaction_columns() -> None:
    if not DATABASE_URL.startswith("sqlite"):
        return

    required_columns = {
        "fuel_sales": {
            "is_reversed": "BOOLEAN NOT NULL DEFAULT 0",
            "reversed_at": "DATETIME",
            "reversed_by": "INTEGER",
        },
        "purchases": {
            "is_reversed": "BOOLEAN NOT NULL DEFAULT 0",
            "reversed_at": "DATETIME",
            "reversed_by": "INTEGER",
        },
        "customer_payments": {
            "is_reversed": "BOOLEAN NOT NULL DEFAULT 0",
            "reversed_at": "DATETIME",
            "reversed_by": "INTEGER",
        },
        "supplier_payments": {
            "is_reversed": "BOOLEAN NOT NULL DEFAULT 0",
            "reversed_at": "DATETIME",
            "reversed_by": "INTEGER",
        },
    }

    inspector = inspect(engine)
    with engine.begin() as connection:
        for table_name, columns in required_columns.items():
            if not inspector.has_table(table_name):
                continue

            existing_columns = {
                column["name"]
                for column in inspect(connection).get_columns(table_name)
            }
            for column_name, definition in columns.items():
                if column_name not in existing_columns:
                    connection.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {definition}"))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
