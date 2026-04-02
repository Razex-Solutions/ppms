import time
from uuid import uuid4

from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.api import ROUTER_REGISTRY
from app.core.config import APP_ENV, ENABLED_MODULES
from app.core.database import engine
from app.core.dependencies import get_current_user
from app.core.logging import get_logger, setup_logging
from app.models import Role, User, Station, FuelType, Tank, Dispenser, Nozzle, FuelSale, Customer, Supplier, Purchase, Tanker, Expense, CustomerPayment, SupplierPayment, NozzleReading, TankDip, Shift, HardwareDevice, HardwareEvent, AuditLog, Organization, ReportExportJob


setup_logging()
logger = get_logger(__name__)


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

    @app.middleware("http")
    async def add_request_context(request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or str(uuid4())
        request.state.request_id = request_id
        started_at = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            duration_ms = round((time.perf_counter() - started_at) * 1000, 2)
            logger.exception(
                "Unhandled request error",
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "duration_ms": duration_ms,
                },
            )
            raise

        duration_ms = round((time.perf_counter() - started_at) * 1000, 2)
        response.headers["X-Request-ID"] = request_id
        logger.info(
            "Request completed",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
            },
        )
        return response

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        request_id = getattr(request.state, "request_id", str(uuid4()))
        logger.warning(
            "HTTP exception",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": exc.status_code,
            },
        )
        response = JSONResponse(
            status_code=exc.status_code,
            content={
                "detail": exc.detail,
                "request_id": request_id,
            },
            headers=exc.headers or None,
        )
        response.headers["X-Request-ID"] = request_id
        return response

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        request_id = getattr(request.state, "request_id", str(uuid4()))
        logger.warning(
            "Validation error",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": 422,
            },
        )
        response = JSONResponse(
            status_code=422,
            content={
                "detail": exc.errors(),
                "request_id": request_id,
            },
        )
        response.headers["X-Request-ID"] = request_id
        return response

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        request_id = getattr(request.state, "request_id", str(uuid4()))
        logger.exception(
            "Unhandled application exception",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": 500,
            },
        )
        response = JSONResponse(
            status_code=500,
            content={
                "detail": "Internal server error",
                "request_id": request_id,
            },
        )
        response.headers["X-Request-ID"] = request_id
        return response

    @app.get("/")
    def read_root():
        return {"message": "PPMS backend is running", "environment": APP_ENV, "enabled_modules": sorted(active_modules)}

    @app.get("/health")
    def health_check():
        return {"status": "ok", "environment": APP_ENV, "enabled_modules": sorted(active_modules)}

    return app


app = create_app()
