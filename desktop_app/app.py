from __future__ import annotations

import tkinter as tk
from tkinter import messagebox, ttk

from desktop_app.api_client import ApiClient, ApiError
from desktop_app.config import SETTINGS
from desktop_app.navigation import NavigationItem, build_navigation
from desktop_app.views.dashboard_view import DashboardView
from desktop_app.views.login_view import LoginView
from desktop_app.views.placeholder_view import PlaceholderView
from desktop_app.views.sales_view import SalesView
from desktop_app.views.sessions_view import SessionsView


class DesktopApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(SETTINGS.app_title)
        self.geometry("1180x760")
        self.minsize(1024, 680)

        self.api_client = ApiClient(SETTINGS.default_api_base_url, SETTINGS.request_timeout_seconds)
        self.root_info: dict = {}
        self.current_user: dict = {}
        self.navigation_items: list[NavigationItem] = []

        self.login_view = LoginView(self, self.handle_login, SETTINGS.default_api_base_url)
        self.login_view.pack(fill="both", expand=True)

        self.shell_frame: ttk.Frame | None = None
        self.content_frame: ttk.Frame | None = None
        self.status_var = tk.StringVar(value="Not connected")
        self.user_var = tk.StringVar(value="")
        self.backend_var = tk.StringVar(value="")
        self.views: dict[str, ttk.Frame] = {}
        self.current_view_key = "dashboard"

    def handle_login(self, base_url: str, username: str, password: str) -> None:
        try:
            self.api_client.set_base_url(base_url)
            self.root_info = self.api_client.get_root_info()
            self.api_client.login(username, password)
            self.current_user = self.api_client.get_current_user()
        except ApiError as exc:
            self.login_view.set_error(str(exc))
            return

        self.backend_var.set(self.api_client.base_url)
        self.user_var.set(
            f"{self.current_user['full_name']} ({self.current_user['role_name']})"
        )
        self.status_var.set("Signed in")
        self.navigation_items = build_navigation(
            self.root_info.get("enabled_modules", []),
            self.current_user.get("permissions", {}),
        )
        self._show_shell()

    def _show_shell(self) -> None:
        self.login_view.pack_forget()
        if self.shell_frame:
            self.shell_frame.destroy()

        self.shell_frame = ttk.Frame(self, padding=0)
        self.shell_frame.pack(fill="both", expand=True)
        self.shell_frame.columnconfigure(1, weight=1)
        self.shell_frame.rowconfigure(1, weight=1)

        header = ttk.Frame(self.shell_frame, padding=12)
        header.grid(row=0, column=0, columnspan=2, sticky="ew")
        header.columnconfigure(1, weight=1)
        ttk.Label(header, text=SETTINGS.app_title, font=("Segoe UI", 14, "bold")).grid(row=0, column=0, sticky="w")
        ttk.Label(header, textvariable=self.backend_var).grid(row=0, column=1, sticky="w", padx=(18, 0))
        ttk.Label(header, textvariable=self.user_var).grid(row=0, column=2, sticky="e", padx=(0, 12))
        ttk.Button(header, text="Refresh", command=self.refresh_current_view).grid(row=0, column=3, padx=4)
        ttk.Button(header, text="Logout", command=self.logout).grid(row=0, column=4, padx=4)

        sidebar = ttk.Frame(self.shell_frame, padding=12)
        sidebar.grid(row=1, column=0, sticky="nsw")
        sidebar.columnconfigure(0, weight=1)

        for row, item in enumerate(self.navigation_items):
            ttk.Button(
                sidebar,
                text=item.title,
                command=lambda item_key=item.key: self.show_view(item_key),
                width=22,
            ).grid(row=row, column=0, sticky="ew", pady=4)

        self.content_frame = ttk.Frame(self.shell_frame, padding=0)
        self.content_frame.grid(row=1, column=1, sticky="nsew")
        self.content_frame.columnconfigure(0, weight=1)
        self.content_frame.rowconfigure(0, weight=1)

        footer = ttk.Frame(self.shell_frame, padding=10)
        footer.grid(row=2, column=0, columnspan=2, sticky="ew")
        ttk.Label(footer, textvariable=self.status_var).pack(side="left")

        self._build_views()
        self.show_view("dashboard")

    def _build_views(self) -> None:
        assert self.content_frame is not None
        self.views = {
            "dashboard": DashboardView(self.content_frame),
            "sales": PlaceholderView(
                self.content_frame,
                "Loading",
                "Preparing sales workspace...",
            ),
            "inventory": PlaceholderView(
                self.content_frame,
                "Inventory Workspace",
                "Inventory, tanks, dispensers, and nozzle operations can be layered here without changing the shell.",
            ),
            "reports": PlaceholderView(
                self.content_frame,
                "Reports Workspace",
                "Organization-aware reports already exist in the backend; this page is the desktop launchpad for them.",
            ),
            "attendance": PlaceholderView(
                self.content_frame,
                "Attendance Workspace",
                "Attendance check-in/out and manual attendance management can be expanded here.",
            ),
            "payroll": PlaceholderView(
                self.content_frame,
                "Payroll Workspace",
                "Payroll runs and payroll approval review can be added here on top of the new backend module.",
            ),
            "notifications": PlaceholderView(
                self.content_frame,
                "Notifications",
                "This area is ready for in-app approval queues, alerts, and outbound delivery diagnostics.",
            ),
            "sessions": SessionsView(self.content_frame),
            "settings": PlaceholderView(
                self.content_frame,
                "Desktop Settings",
                "Future local settings can live here, including printers, station defaults, and hardware client preferences.",
            ),
        }

        for view in self.views.values():
            view.grid(row=0, column=0, sticky="nsew")

        self.views["sales"].destroy()
        self.views["sales"] = SalesView(
            self.content_frame,
            on_submit=self.submit_sale,
            on_refresh=lambda: self._load_view_data("sales"),
            on_station_change=self.load_sales_for_station,
        )
        self.views["sales"].grid(row=0, column=0, sticky="nsew")

    def show_view(self, view_key: str) -> None:
        view = self.views.get(view_key)
        if not view:
            return
        self.current_view_key = view_key
        view.tkraise()
        self.status_var.set(f"Viewing {view_key}")
        self._load_view_data(view_key)

    def refresh_current_view(self) -> None:
        self._load_view_data(self.current_view_key)

    def _load_view_data(self, view_key: str) -> None:
        try:
            if view_key == "dashboard":
                payload = self.api_client.get_dashboard(
                    station_id=self.current_user.get("station_id"),
                    organization_id=self.current_user.get("organization_id"),
                )
                dashboard_view = self.views["dashboard"]
                if isinstance(dashboard_view, DashboardView):
                    dashboard_view.load_data(payload)
                    self.status_var.set("Dashboard refreshed")
            elif view_key == "sessions":
                sessions = self.api_client.list_sessions()
                sessions_view = self.views["sessions"]
                if isinstance(sessions_view, SessionsView):
                    sessions_view.load_data(sessions)
                    self.status_var.set("Sessions refreshed")
            elif view_key == "sales":
                sales_view = self.views["sales"]
                if isinstance(sales_view, SalesView):
                    stations = self.api_client.list_stations()
                    preferred_station_id = self.current_user.get("station_id")
                    station_nozzles: dict[int, list[dict]] = {}
                    station_customers: dict[int, list[dict]] = {}
                    for station in stations:
                        station_id = station["id"]
                        station_nozzles[station_id] = self.api_client.list_nozzles(station_id=station_id)
                        station_customers[station_id] = self.api_client.list_customers(station_id=station_id)
                    fuel_types = self.api_client.list_fuel_types()
                    active_station_id = preferred_station_id or (stations[0]["id"] if stations else None)
                    sales_view.load_reference_data(
                        stations=stations,
                        station_nozzles=station_nozzles,
                        station_customers=station_customers,
                        fuel_types=fuel_types,
                        preferred_station_id=active_station_id,
                    )
                    sales_view.set_feedback("Sales workspace refreshed from backend data.")
                    self.status_var.set("Sales workspace refreshed")
        except ApiError as exc:
            messagebox.showerror("PPMS Desktop", str(exc))
            self.status_var.set(str(exc))

    def load_sales_for_station(self, station_id: int) -> None:
        try:
            recent_sales = self.api_client.list_fuel_sales(station_id=station_id, limit=25)
            sales_view = self.views.get("sales")
            if isinstance(sales_view, SalesView):
                sales_view.load_recent_sales(recent_sales)
            self.status_var.set("Sales list refreshed")
        except ApiError as exc:
            messagebox.showerror("Fuel Sales", str(exc))
            self.status_var.set(str(exc))

    def submit_sale(self, payload: dict) -> None:
        try:
            created_sale = self.api_client.create_fuel_sale(payload)
            sales_view = self.views["sales"]
            if isinstance(sales_view, SalesView):
                station_id = payload.get("station_id")
                recent_sales = self.api_client.list_fuel_sales(station_id=station_id, limit=25)
                sales_view.load_recent_sales(recent_sales)
                sales_view.reset_after_submit()
                sales_view.set_feedback(
                    f"Sale #{created_sale['id']} created: {created_sale['quantity']:.2f}L for {created_sale['total_amount']:.2f}."
                )
            self.status_var.set("Fuel sale created")
        except ApiError as exc:
            messagebox.showerror("Fuel Sale", str(exc))
            sales_view = self.views.get("sales")
            if isinstance(sales_view, SalesView):
                sales_view.set_feedback(str(exc))
            self.status_var.set(str(exc))

    def logout(self) -> None:
        try:
            self.api_client.logout()
        except ApiError:
            pass
        if self.shell_frame:
            self.shell_frame.destroy()
            self.shell_frame = None
        self.current_user = {}
        self.root_info = {}
        self.current_view_key = "dashboard"
        self.status_var.set("Not connected")
        self.user_var.set("")
        self.backend_var.set("")
        self.login_view = LoginView(self, self.handle_login, self.api_client.base_url)
        self.login_view.pack(fill="both", expand=True)


def run_desktop_app() -> None:
    app = DesktopApp()
    app.mainloop()
