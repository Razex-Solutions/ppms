from datetime import timedelta

from app.core.time import utc_now

MAX_DELIVERY_ATTEMPTS = 3
RETRY_BASE_MINUTES = 5


def next_retry_time(attempts_count: int):
    delay_minutes = RETRY_BASE_MINUTES * (2 ** max(attempts_count - 1, 0))
    return utc_now() + timedelta(minutes=delay_minutes)


def should_retry(status: str, attempts_count: int) -> bool:
    return status == "failed" and attempts_count < MAX_DELIVERY_ATTEMPTS
