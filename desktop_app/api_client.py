from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import requests


class ApiError(Exception):
    """Raised when the desktop client cannot complete an API request."""

    def __init__(self, message: str, status_code: int | None = None):
        super().__init__(message)
        self.status_code = status_code


@dataclass
class AuthTokens:
    access_token: str
    refresh_token: str


class ApiClient:
    def __init__(self, base_url: str, timeout_seconds: float = 20):
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self._session = requests.Session()
        self._tokens: AuthTokens | None = None

    @property
    def is_authenticated(self) -> bool:
        return self._tokens is not None

    def set_base_url(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/")

    def login(self, username: str, password: str) -> dict[str, Any]:
        payload = self._request(
            "POST",
            "/auth/login",
            auth_required=False,
            json={"username": username, "password": password},
        )
        self._tokens = AuthTokens(
            access_token=payload["access_token"],
            refresh_token=payload["refresh_token"],
        )
        return payload

    def logout(self) -> None:
        if not self.is_authenticated:
            return
        try:
            self._request("POST", "/auth/logout", allow_refresh=False)
        finally:
            self._tokens = None

    def get_root_info(self) -> dict[str, Any]:
        return self._request("GET", "/", auth_required=False, allow_refresh=False)

    def get_health(self) -> dict[str, Any]:
        return self._request("GET", "/health", auth_required=False, allow_refresh=False)

    def get_current_user(self) -> dict[str, Any]:
        return self._request("GET", "/auth/me")

    def list_sessions(self) -> list[dict[str, Any]]:
        return self._request("GET", "/auth/sessions")

    def get_dashboard(self, station_id: int | None = None, organization_id: int | None = None) -> dict[str, Any]:
        params: dict[str, Any] = {}
        if station_id is not None:
            params["station_id"] = station_id
        if organization_id is not None:
            params["organization_id"] = organization_id
        return self._request("GET", "/dashboard/", params=params)

    def list_stations(self) -> list[dict[str, Any]]:
        return self._request("GET", "/stations/")

    def list_nozzles(self, station_id: int | None = None) -> list[dict[str, Any]]:
        params: dict[str, Any] = {}
        if station_id is not None:
            params["station_id"] = station_id
        return self._request("GET", "/nozzles/", params=params)

    def list_fuel_types(self) -> list[dict[str, Any]]:
        return self._request("GET", "/fuel-types/")

    def list_customers(self, station_id: int | None = None) -> list[dict[str, Any]]:
        params: dict[str, Any] = {}
        if station_id is not None:
            params["station_id"] = station_id
        return self._request("GET", "/customers/", params=params)

    def list_fuel_sales(self, station_id: int | None = None, limit: int = 25) -> list[dict[str, Any]]:
        params: dict[str, Any] = {"limit": limit}
        if station_id is not None:
            params["station_id"] = station_id
        return self._request("GET", "/fuel-sales/", params=params)

    def create_fuel_sale(self, payload: dict[str, Any]) -> dict[str, Any]:
        return self._request("POST", "/fuel-sales/", json=payload)

    def _refresh_tokens(self) -> None:
        if not self._tokens:
            raise ApiError("Session expired. Please sign in again.", status_code=401)

        response = self._session.post(
            self._url("/auth/refresh"),
            json={"refresh_token": self._tokens.refresh_token},
            timeout=self.timeout_seconds,
        )
        if response.status_code >= 400:
            self._tokens = None
            raise self._build_api_error(response)

        payload = response.json()
        self._tokens = AuthTokens(
            access_token=payload["access_token"],
            refresh_token=payload["refresh_token"],
        )

    def _request(
        self,
        method: str,
        path: str,
        *,
        auth_required: bool = True,
        allow_refresh: bool = True,
        **kwargs: Any,
    ) -> Any:
        headers = dict(kwargs.pop("headers", {}))
        if auth_required and self._tokens:
            headers["Authorization"] = f"Bearer {self._tokens.access_token}"

        try:
            response = self._session.request(
                method,
                self._url(path),
                headers=headers,
                timeout=self.timeout_seconds,
                **kwargs,
            )
        except requests.RequestException as exc:
            raise ApiError(f"Unable to reach PPMS backend: {exc}") from exc

        if response.status_code == 401 and auth_required and allow_refresh and self._tokens:
            self._refresh_tokens()
            return self._request(
                method,
                path,
                auth_required=auth_required,
                allow_refresh=False,
                headers=kwargs.pop("headers", None) or {},
                **kwargs,
            )

        if response.status_code >= 400:
            raise self._build_api_error(response)

        if not response.content:
            return None
        return response.json()

    def _build_api_error(self, response: requests.Response) -> ApiError:
        try:
            payload = response.json()
        except ValueError:
            payload = {}
        detail = payload.get("detail")
        if isinstance(detail, list):
            message = "; ".join(item.get("msg", "Validation error") for item in detail)
        else:
            message = detail or response.text or "Request failed"
        return ApiError(message, status_code=response.status_code)

    def _url(self, path: str) -> str:
        return f"{self.base_url}{path}"
