from fastapi import FastAPI, Depends

from app.api import ROUTER_REGISTRY
from app.core.config import ENABLED_MODULES
from app.core.database import Base, engine, ensure_sqlite_transaction_columns
from app.core.dependencies import get_current_user
from app.models import Role, User, Station, FuelType, Tank, Dispenser, Nozzle, FuelSale, Customer, Supplier, Purchase, Tanker, Expense, CustomerPayment, SupplierPayment, NozzleReading, TankDip, Shift, HardwareDevice, HardwareEvent


Base.metadata.create_all(bind=engine)
ensure_sqlite_transaction_columns()

def _resolve_enabled_modules(enabled_modules: str | None) -> set[str]:
    configured = (enabled_modules or ENABLED_MODULES).strip()
    if configured == "*" or configured == "":
        return {entry["name"] for entry in ROUTER_REGISTRY}

    return {
        item.strip()
        for item in configured.split(",")
        if item.strip()
    }


def create_app(enabled_modules: str | None = None) -> FastAPI:
    app = FastAPI(
        title="Petrol Pump Management System API",
        version="0.1.0"
    )

    protected = {"dependencies": [Depends(get_current_user)]}
    active_modules = _resolve_enabled_modules(enabled_modules)

    for entry in ROUTER_REGISTRY:
        if entry["name"] not in active_modules:
            continue
        app.include_router(entry["router"], **(protected if entry["protected"] else {}))

    @app.get("/")
    def read_root():
        return {"message": "PPMS backend is running", "enabled_modules": sorted(active_modules)}

    @app.get("/health")
    def health_check():
        return {"status": "ok", "enabled_modules": sorted(active_modules)}

    return app


app = create_app()
