import json

import requests
from fastapi import HTTPException

from app.core.config import APP_ENV, HARDWARE_VENDOR_MODE
from app.models.hardware_device import HardwareDevice


RECOGNIZED_VENDORS = {"veederroot", "tokheim", "gilbarco", "opw"}


class HardwareAdapter:
    def ensure_supported(self, device: HardwareDevice) -> None:
        raise NotImplementedError

    def health_check(self, device: HardwareDevice) -> dict:
        raise NotImplementedError

    def fetch_snapshot(self, device: HardwareDevice) -> dict:
        raise NotImplementedError


class SimulatedHardwareAdapter(HardwareAdapter):
    def ensure_supported(self, device: HardwareDevice) -> None:
        if device.integration_mode != "simulated":
            raise HTTPException(status_code=400, detail="Selected hardware device is not configured for simulated ingestion")

    def health_check(self, device: HardwareDevice) -> dict:
        self.ensure_supported(device)
        return {
            "status": "ok",
            "mode": "simulated",
            "vendor_name": device.vendor_name or "simulator",
            "detail": "Simulated adapter is ready for local testing",
        }

    def fetch_snapshot(self, device: HardwareDevice) -> dict:
        self.ensure_supported(device)
        raise HTTPException(status_code=400, detail="Simulated devices use the simulation ingestion endpoints instead of vendor polling")


class VendorAPIHardwareAdapter(HardwareAdapter):
    vendor_name: str = "generic"
    default_protocol: str = "https"

    def ensure_supported(self, device: HardwareDevice) -> None:
        if device.integration_mode != "vendor_api":
            raise HTTPException(status_code=400, detail="Selected hardware device is not configured for vendor API integration")
        vendor_name = (device.vendor_name or "").strip().lower()
        if vendor_name != self.vendor_name:
            raise HTTPException(status_code=400, detail=f"Device is not configured for the {self.vendor_name} adapter")
        if not device.device_identifier:
            raise HTTPException(status_code=400, detail="Device identifier is required for vendor API devices")
        if HARDWARE_VENDOR_MODE != "mock" and APP_ENV not in {"development", "test"} and not device.endpoint_url:
            raise HTTPException(status_code=400, detail="Endpoint URL is required for live vendor polling")

    def health_check(self, device: HardwareDevice) -> dict:
        self.ensure_supported(device)
        return {
            "status": "configured",
            "mode": "vendor_api",
            "vendor_name": self.vendor_name,
            "protocol": device.protocol or self.default_protocol,
            "device_identifier": device.device_identifier,
            "detail": f"{self.vendor_name} adapter is ready for vendor polling",
        }

    def fetch_snapshot(self, device: HardwareDevice) -> dict:
        self.ensure_supported(device)
        if HARDWARE_VENDOR_MODE == "mock" or APP_ENV in {"development", "test"}:
            return self.mock_snapshot(device)
        return self.live_snapshot(device)

    def mock_snapshot(self, device: HardwareDevice) -> dict:
        raise NotImplementedError

    def build_live_url(self, device: HardwareDevice) -> str:
        if not device.endpoint_url:
            raise HTTPException(status_code=400, detail="Endpoint URL is required for live vendor polling")
        return device.endpoint_url

    def build_headers(self, device: HardwareDevice) -> dict:
        headers = {"Accept": "application/json"}
        if device.api_key:
            headers["X-API-Key"] = device.api_key
        return headers

    def live_snapshot(self, device: HardwareDevice) -> dict:
        try:
            response = requests.get(self.build_live_url(device), headers=self.build_headers(device), timeout=20)
        except Exception as exc:
            raise HTTPException(status_code=502, detail=f"{self.vendor_name} polling failed: {exc}") from exc
        if not response.ok:
            raise HTTPException(status_code=502, detail=f"{self.vendor_name} polling failed with HTTP {response.status_code}")
        try:
            return response.json()
        except json.JSONDecodeError as exc:
            raise HTTPException(status_code=502, detail=f"{self.vendor_name} polling returned invalid JSON") from exc


class VeederRootAdapter(VendorAPIHardwareAdapter):
    vendor_name = "veederroot"
    default_protocol = "https"

    def mock_snapshot(self, device: HardwareDevice) -> dict:
        return {
            "vendor": self.vendor_name,
            "device_identifier": device.device_identifier,
            "tank_volume": 92.5,
            "temperature": 24.3,
            "status": "received",
            "notes": "Mock Veeder-Root tank probe snapshot",
        }


class TokheimAdapter(VendorAPIHardwareAdapter):
    vendor_name = "tokheim"
    default_protocol = "http"

    def mock_snapshot(self, device: HardwareDevice) -> dict:
        return {
            "vendor": self.vendor_name,
            "device_identifier": device.device_identifier,
            "meter_reading": 1012.0,
            "volume": 12.0,
            "status": "received",
            "notes": "Mock Tokheim dispenser snapshot",
        }


class GilbarcoAdapter(VendorAPIHardwareAdapter):
    vendor_name = "gilbarco"
    default_protocol = "https"

    def mock_snapshot(self, device: HardwareDevice) -> dict:
        return {
            "vendor": self.vendor_name,
            "device_identifier": device.device_identifier,
            "meter_reading": 1015.5,
            "volume": 15.5,
            "status": "received",
            "notes": "Mock Gilbarco dispenser snapshot",
        }


class OPWAdapter(VendorAPIHardwareAdapter):
    vendor_name = "opw"
    default_protocol = "https"

    def mock_snapshot(self, device: HardwareDevice) -> dict:
        return {
            "vendor": self.vendor_name,
            "device_identifier": device.device_identifier,
            "tank_volume": 88.0,
            "temperature": 23.1,
            "status": "received",
            "notes": "Mock OPW tank probe snapshot",
        }


class GenericVendorAdapter(VendorAPIHardwareAdapter):
    vendor_name = "generic"

    def ensure_supported(self, device: HardwareDevice) -> None:
        if device.integration_mode != "vendor_api":
            raise HTTPException(status_code=400, detail="Selected hardware device is not configured for vendor API integration")
        if not device.device_identifier:
            raise HTTPException(status_code=400, detail="Device identifier is required for vendor API devices")
        if HARDWARE_VENDOR_MODE != "mock" and APP_ENV not in {"development", "test"} and not device.endpoint_url:
            raise HTTPException(status_code=400, detail="Endpoint URL is required for live vendor polling")

    def health_check(self, device: HardwareDevice) -> dict:
        self.ensure_supported(device)
        return {
            "status": "unverified",
            "mode": "vendor_api",
            "vendor_name": (device.vendor_name or "generic").lower(),
            "protocol": device.protocol or self.default_protocol,
            "device_identifier": device.device_identifier,
            "detail": "Generic vendor adapter is configured but may need custom mapping",
        }

    def mock_snapshot(self, device: HardwareDevice) -> dict:
        if device.device_type == "tank_probe":
            return {
                "vendor": (device.vendor_name or "generic").lower(),
                "device_identifier": device.device_identifier,
                "tank_volume": 90.0,
                "temperature": 22.0,
                "status": "received",
                "notes": "Mock generic tank probe snapshot",
            }
        return {
            "vendor": (device.vendor_name or "generic").lower(),
            "device_identifier": device.device_identifier,
            "meter_reading": 1008.0,
            "volume": 8.0,
            "status": "received",
            "notes": "Mock generic dispenser snapshot",
        }


def get_hardware_adapter(device: HardwareDevice) -> HardwareAdapter:
    if device.integration_mode != "vendor_api":
        return SimulatedHardwareAdapter()

    vendor_name = (device.vendor_name or "").strip().lower()
    if vendor_name == "veederroot":
        return VeederRootAdapter()
    if vendor_name == "tokheim":
        return TokheimAdapter()
    if vendor_name == "gilbarco":
        return GilbarcoAdapter()
    if vendor_name == "opw":
        return OPWAdapter()
    return GenericVendorAdapter()
