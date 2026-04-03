from fastapi import HTTPException

from app.models.hardware_device import HardwareDevice


class HardwareAdapter:
    def ensure_supported(self, device: HardwareDevice) -> None:
        raise NotImplementedError

    def health_check(self, device: HardwareDevice) -> dict:
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


class VendorAPIHardwareAdapter(HardwareAdapter):
    def ensure_supported(self, device: HardwareDevice) -> None:
        if device.integration_mode != "vendor_api":
            raise HTTPException(status_code=400, detail="Selected hardware device is not configured for vendor API integration")

    def health_check(self, device: HardwareDevice) -> dict:
        self.ensure_supported(device)
        vendor_name = (device.vendor_name or "").strip().lower()
        if not vendor_name:
            raise HTTPException(status_code=400, detail="Vendor name is required for vendor API hardware checks")
        if vendor_name in {"veederroot", "tokheim", "gilbarco", "opw"}:
            return {
                "status": "configured",
                "mode": "vendor_api",
                "vendor_name": vendor_name,
                "detail": "Vendor adapter profile recognized; endpoint wiring can be added later with credentials",
            }
        return {
            "status": "unverified",
            "mode": "vendor_api",
            "vendor_name": vendor_name,
            "detail": "Vendor adapter is generic; custom endpoint mapping is still required",
        }


def get_hardware_adapter(device: HardwareDevice) -> HardwareAdapter:
    if device.integration_mode == "vendor_api":
        return VendorAPIHardwareAdapter()
    return SimulatedHardwareAdapter()
