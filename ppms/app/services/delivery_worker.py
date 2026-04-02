import asyncio

from app.core.database import SessionLocal
from app.core.logging import get_logger
from app.services.financial_documents import process_due_financial_document_dispatches
from app.services.notifications import process_due_notification_deliveries


logger = get_logger(__name__)


def process_delivery_queue_once() -> dict:
    db = SessionLocal()
    try:
        notifications = process_due_notification_deliveries(db, limit=100)
        documents = process_due_financial_document_dispatches(db, limit=100)
        return {
            "notification_deliveries_processed": notifications["processed"],
            "financial_document_dispatches_processed": documents["processed"],
        }
    finally:
        db.close()


async def run_delivery_worker(interval_seconds: int) -> None:
    while True:
        try:
            result = process_delivery_queue_once()
            total = result["notification_deliveries_processed"] + result["financial_document_dispatches_processed"]
            if total:
                logger.info(
                    "Processed due delivery queue items",
                    extra={"delivery_worker": True, **result},
                )
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Delivery worker iteration failed", extra={"delivery_worker": True})
        await asyncio.sleep(interval_seconds)
