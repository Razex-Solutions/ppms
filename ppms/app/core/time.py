from datetime import datetime, UTC


def utc_now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)
