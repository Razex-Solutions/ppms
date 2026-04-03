from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Callable


class SalesView(ttk.Frame):
    def __init__(
        self,
        master: tk.Misc,
        on_submit: Callable[[dict], None],
        on_refresh: Callable[[], None],
        on_station_change: Callable[[int], None],
    ):
        super().__init__(master, padding=16)
        self.on_submit = on_submit
        self.on_refresh = on_refresh
        self.on_station_change = on_station_change
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(1, weight=1)

        ttk.Label(self, text="Forecourt Sales", font=("Segoe UI", 16, "bold")).grid(
            row=0, column=0, sticky="w", pady=(0, 12)
        )

        top = ttk.Frame(self)
        top.grid(row=1, column=0, columnspan=2, sticky="nsew")
        top.columnconfigure(0, weight=1)
        top.columnconfigure(1, weight=1)

        form = ttk.LabelFrame(top, text="Create Fuel Sale", padding=14)
        form.grid(row=0, column=0, sticky="nsew", padx=(0, 8))
        form.columnconfigure(1, weight=1)

        self.station_var = tk.StringVar()
        self.nozzle_var = tk.StringVar()
        self.sale_type_var = tk.StringVar(value="cash")
        self.customer_var = tk.StringVar()
        self.rate_var = tk.StringVar()
        self.closing_meter_var = tk.StringVar()
        self.shift_name_var = tk.StringVar()
        self.feedback_var = tk.StringVar(value="Select a nozzle and enter the closing meter.")
        self.nozzle_detail_var = tk.StringVar(value="")

        ttk.Label(form, text="Station").grid(row=0, column=0, sticky="w", pady=4)
        self.station_combo = ttk.Combobox(form, state="readonly", textvariable=self.station_var)
        self.station_combo.grid(row=0, column=1, sticky="ew", pady=4)
        self.station_combo.bind("<<ComboboxSelected>>", lambda _event: self._on_station_changed())

        ttk.Label(form, text="Nozzle").grid(row=1, column=0, sticky="w", pady=4)
        self.nozzle_combo = ttk.Combobox(form, state="readonly", textvariable=self.nozzle_var)
        self.nozzle_combo.grid(row=1, column=1, sticky="ew", pady=4)
        self.nozzle_combo.bind("<<ComboboxSelected>>", lambda _event: self._on_nozzle_changed())

        ttk.Label(form, textvariable=self.nozzle_detail_var, wraplength=380, justify="left").grid(
            row=2, column=0, columnspan=2, sticky="w", pady=(0, 8)
        )

        ttk.Label(form, text="Sale Type").grid(row=3, column=0, sticky="w", pady=4)
        sale_type_combo = ttk.Combobox(form, state="readonly", textvariable=self.sale_type_var, values=["cash", "credit"])
        sale_type_combo.grid(row=3, column=1, sticky="ew", pady=4)
        sale_type_combo.bind("<<ComboboxSelected>>", lambda _event: self._toggle_customer_state())

        ttk.Label(form, text="Customer").grid(row=4, column=0, sticky="w", pady=4)
        self.customer_combo = ttk.Combobox(form, state="disabled", textvariable=self.customer_var)
        self.customer_combo.grid(row=4, column=1, sticky="ew", pady=4)

        ttk.Label(form, text="Rate Per Liter").grid(row=5, column=0, sticky="w", pady=4)
        ttk.Entry(form, textvariable=self.rate_var).grid(row=5, column=1, sticky="ew", pady=4)

        ttk.Label(form, text="Closing Meter").grid(row=6, column=0, sticky="w", pady=4)
        ttk.Entry(form, textvariable=self.closing_meter_var).grid(row=6, column=1, sticky="ew", pady=4)

        ttk.Label(form, text="Shift Name").grid(row=7, column=0, sticky="w", pady=4)
        ttk.Entry(form, textvariable=self.shift_name_var).grid(row=7, column=1, sticky="ew", pady=4)

        action_row = ttk.Frame(form)
        action_row.grid(row=8, column=0, columnspan=2, sticky="ew", pady=(12, 0))
        ttk.Button(action_row, text="Submit Sale", command=self._submit).pack(side="right", padx=4)
        ttk.Button(action_row, text="Refresh Data", command=self.on_refresh).pack(side="right", padx=4)

        ttk.Label(form, textvariable=self.feedback_var, wraplength=380, justify="left").grid(
            row=9, column=0, columnspan=2, sticky="w", pady=(10, 0)
        )

        recent = ttk.LabelFrame(top, text="Recent Fuel Sales", padding=14)
        recent.grid(row=0, column=1, sticky="nsew", padx=(8, 0))
        recent.columnconfigure(0, weight=1)
        recent.rowconfigure(0, weight=1)

        columns = ("created_at", "nozzle_id", "quantity", "sale_type", "total_amount", "shift_name")
        self.sales_tree = ttk.Treeview(recent, columns=columns, show="headings", height=16)
        for column, title, width in (
            ("created_at", "Created", 150),
            ("nozzle_id", "Nozzle", 80),
            ("quantity", "Liters", 80),
            ("sale_type", "Type", 90),
            ("total_amount", "Amount", 100),
            ("shift_name", "Shift", 100),
        ):
            self.sales_tree.heading(column, text=title)
            self.sales_tree.column(column, width=width, anchor="w")
        self.sales_tree.grid(row=0, column=0, sticky="nsew")

        self.station_map: dict[str, dict] = {}
        self.nozzle_map: dict[str, dict] = {}
        self.customer_map: dict[str, dict] = {}
        self.fuel_type_map: dict[int, dict] = {}
        self.station_nozzles: dict[int, list[dict]] = {}
        self.station_customers: dict[int, list[dict]] = {}

    def load_reference_data(
        self,
        *,
        stations: list[dict],
        station_nozzles: dict[int, list[dict]],
        station_customers: dict[int, list[dict]],
        fuel_types: list[dict],
        preferred_station_id: int | None,
    ) -> None:
        self.station_map = {
            self._station_label(station): station for station in stations
        }
        self.nozzle_map = {}
        self.customer_map = {}
        self.fuel_type_map = {fuel_type["id"]: fuel_type for fuel_type in fuel_types}
        self.station_nozzles = station_nozzles
        self.station_customers = station_customers

        station_labels = list(self.station_map.keys())
        self.station_combo["values"] = station_labels
        if station_labels:
            default_station_label = next(
                (label for label, station in self.station_map.items() if station["id"] == preferred_station_id),
                station_labels[0],
            )
            self.station_var.set(default_station_label)
            self._on_station_changed()

    def load_recent_sales(self, sales: list[dict]) -> None:
        for item in self.sales_tree.get_children():
            self.sales_tree.delete(item)
        for sale in sales:
            self.sales_tree.insert(
                "",
                "end",
                values=(
                    str(sale.get("created_at", ""))[:19].replace("T", " "),
                    sale.get("nozzle_id"),
                    f"{sale.get('quantity', 0):,.2f}",
                    sale.get("sale_type", ""),
                    f"{sale.get('total_amount', 0):,.2f}",
                    sale.get("shift_name") or "-",
                ),
            )

    def set_feedback(self, message: str) -> None:
        self.feedback_var.set(message)

    def _on_station_changed(self) -> None:
        station = self.station_map.get(self.station_var.get())
        station_id = station["id"] if station else None

        nozzles = self.station_nozzles.get(station_id, [])
        nozzle_labels = []
        self.nozzle_map = {}
        for nozzle in sorted(nozzles, key=lambda item: item["code"]):
            label = self._nozzle_label(nozzle)
            self.nozzle_map[label] = nozzle
            nozzle_labels.append(label)
        self.nozzle_combo["values"] = nozzle_labels
        self.nozzle_var.set(nozzle_labels[0] if nozzle_labels else "")
        self._on_nozzle_changed()

        customers = self.station_customers.get(station_id, [])
        customer_labels = ["Walk-in / cash customer"]
        self.customer_map = {}
        for customer in sorted(customers, key=lambda item: item["name"]):
            label = self._customer_label(customer)
            self.customer_map[label] = customer
            customer_labels.append(label)
        self.customer_combo["values"] = customer_labels
        self.customer_var.set(customer_labels[0] if customer_labels else "")
        self._toggle_customer_state()
        if station_id is not None:
            self.on_station_change(station_id)

    def _on_nozzle_changed(self) -> None:
        nozzle = self.nozzle_map.get(self.nozzle_var.get())
        if not nozzle:
            self.nozzle_detail_var.set("No nozzle selected.")
            return
        fuel_type = self.fuel_type_map.get(nozzle["fuel_type_id"], {})
        self.nozzle_detail_var.set(
            f"Nozzle code {nozzle['code']} | Fuel {fuel_type.get('name', nozzle['fuel_type_id'])} | "
            f"Current meter {nozzle['meter_reading']:,.2f} | Segment start {nozzle['current_segment_start_reading']:,.2f}"
        )

    def _toggle_customer_state(self) -> None:
        if self.sale_type_var.get() == "credit":
            self.customer_combo.configure(state="readonly")
            if not self.customer_var.get() or self.customer_var.get() == "Walk-in / cash customer":
                customer_values = list(self.customer_combo["values"])
                if len(customer_values) > 1:
                    self.customer_var.set(customer_values[1])
        else:
            self.customer_combo.configure(state="disabled")
            self.customer_var.set("Walk-in / cash customer")

    def _submit(self) -> None:
        station = self.station_map.get(self.station_var.get())
        nozzle = self.nozzle_map.get(self.nozzle_var.get())
        if not station or not nozzle:
            self.set_feedback("Select a station and nozzle before submitting a sale.")
            return

        try:
            closing_meter = float(self.closing_meter_var.get())
            rate_per_liter = float(self.rate_var.get())
        except ValueError:
            self.set_feedback("Closing meter and rate per liter must be valid numbers.")
            return

        payload = {
            "station_id": station["id"],
            "nozzle_id": nozzle["id"],
            "fuel_type_id": nozzle["fuel_type_id"],
            "closing_meter": closing_meter,
            "rate_per_liter": rate_per_liter,
            "sale_type": self.sale_type_var.get(),
            "shift_name": self.shift_name_var.get().strip() or None,
        }

        if self.sale_type_var.get() == "credit":
            customer = self.customer_map.get(self.customer_var.get())
            if not customer:
                self.set_feedback("Credit sales require a selected customer.")
                return
            payload["customer_id"] = customer["id"]

        self.on_submit(payload)

    def reset_after_submit(self) -> None:
        self.closing_meter_var.set("")
        self.shift_name_var.set("")
        self.set_feedback("Sale saved. You can enter the next sale now.")
        self._on_station_changed()

    def _station_label(self, station: dict) -> str:
        return f"{station['name']} ({station['code']})"

    def _nozzle_label(self, nozzle: dict) -> str:
        return f"{nozzle['code']} - {nozzle['name']}"

    def _customer_label(self, customer: dict) -> str:
        return f"{customer['code']} - {customer['name']}"
