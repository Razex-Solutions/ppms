from dataclasses import dataclass
import os

from dotenv import load_dotenv


load_dotenv()


@dataclass(frozen=True)
class DesktopSettings:
    app_title: str = os.getenv("PPMS_DESKTOP_APP_TITLE", "PPMS Desktop")
    default_api_base_url: str = os.getenv("PPMS_DESKTOP_API_BASE_URL", "http://127.0.0.1:8012")
    request_timeout_seconds: float = float(os.getenv("PPMS_DESKTOP_REQUEST_TIMEOUT", "20"))


SETTINGS = DesktopSettings()
