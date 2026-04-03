from __future__ import annotations

import tkinter as tk
from tkinter import ttk


class DashboardView(ttk.Frame):
    def __init__(self, master: tk.Misc):
        super().__init__(master, padding=16)
        self.columnconfigure(0, weight=1)

        ttk.Label(self, text="Dashboard", font=("Segoe UI", 16, "bold")).grid(
            row=0, column=0, sticky="w", pady=(0, 12)
        )

        cards = ttk.Frame(self)
        cards.grid(row=1, column=0, sticky="ew")
        for index in range(4):
            cards.columnconfigure(index, weight=1)

        self.metric_vars = {
            "sales": tk.StringVar(value="0.00"),
            "expenses": tk.StringVar(value="0.00"),
            "profit": tk.StringVar(value="0.00"),
            "stock": tk.StringVar(value="0.00"),
        }

        self._build_card(cards, 0, "Sales", self.metric_vars["sales"])
        self._build_card(cards, 1, "Expenses", self.metric_vars["expenses"])
        self._build_card(cards, 2, "Net Profit", self.metric_vars["profit"])
        self._build_card(cards, 3, "Fuel Stock (L)", self.metric_vars["stock"])

        self.summary_var = tk.StringVar(value="No dashboard data loaded yet.")
        ttk.Label(self, textvariable=self.summary_var, wraplength=820, justify="left").grid(
            row=2, column=0, sticky="w", pady=(16, 8)
        )

        alert_frame = ttk.LabelFrame(self, text="Alerts", padding=12)
        alert_frame.grid(row=3, column=0, sticky="nsew")
        alert_frame.columnconfigure(0, weight=1)

        self.alerts_text = tk.Text(alert_frame, height=14, wrap="word")
        self.alerts_text.grid(row=0, column=0, sticky="nsew")
        self.alerts_text.configure(state="disabled")

    def load_data(self, payload: dict) -> None:
        sales = payload.get("sales", {})
        self.metric_vars["sales"].set(f"{sales.get('total', 0):,.2f}")
        self.metric_vars["expenses"].set(f"{payload.get('expenses', 0):,.2f}")
        self.metric_vars["profit"].set(f"{payload.get('net_profit', 0):,.2f}")
        self.metric_vars["stock"].set(f"{payload.get('fuel_stock_liters', 0):,.2f}")

        filters = payload.get("filters", {})
        station_scope = filters.get("station_id") or "auto"
        organization_scope = filters.get("organization_id") or "auto"
        self.summary_var.set(
            f"Loaded dashboard scope: station={station_scope}, organization={organization_scope}. "
            f"Cash sales {sales.get('cash', 0):,.2f}, credit sales {sales.get('credit', 0):,.2f}, "
            f"receivables {payload.get('receivables', 0):,.2f}, payables {payload.get('payables', 0):,.2f}."
        )

        lines: list[str] = []
        low_stock_alerts = payload.get("low_stock_alerts", [])
        credit_alerts = payload.get("credit_limit_alerts", [])
        tanker = payload.get("tanker", {})

        if low_stock_alerts:
            lines.append("Low stock")
            for alert in low_stock_alerts:
                lines.append(
                    f"- {alert['tank_name']}: {alert['current_volume']}L remaining, threshold {alert['threshold']}L"
                )
        if credit_alerts:
            lines.append("Credit limit warnings")
            for alert in credit_alerts:
                lines.append(
                    f"- {alert['customer_name']}: {alert['usage_percentage']}% of limit used"
                )
        lines.append(
            f"Tanker summary: {tanker.get('completed_trips', 0)} completed trips, "
            f"net profit {tanker.get('net_profit', 0):,.2f}"
        )

        self.alerts_text.configure(state="normal")
        self.alerts_text.delete("1.0", tk.END)
        self.alerts_text.insert("1.0", "\n".join(lines) if lines else "No active alerts.")
        self.alerts_text.configure(state="disabled")

    def _build_card(self, master: ttk.Frame, column: int, title: str, variable: tk.StringVar) -> None:
        card = ttk.LabelFrame(master, text=title, padding=12)
        card.grid(row=0, column=column, sticky="nsew", padx=6)
        ttk.Label(card, textvariable=variable, font=("Segoe UI", 18, "bold")).grid(row=0, column=0, sticky="w")
