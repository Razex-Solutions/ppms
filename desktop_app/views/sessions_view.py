from __future__ import annotations

import tkinter as tk
from tkinter import ttk


class SessionsView(ttk.Frame):
    def __init__(self, master: tk.Misc):
        super().__init__(master, padding=16)
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        ttk.Label(self, text="Active Sessions", font=("Segoe UI", 16, "bold")).grid(
            row=0, column=0, sticky="w", pady=(0, 12)
        )

        columns = ("created_at", "expires_at", "last_seen_at", "ip_address", "is_active")
        self.tree = ttk.Treeview(self, columns=columns, show="headings", height=10)
        for column, title in (
            ("created_at", "Created"),
            ("expires_at", "Expires"),
            ("last_seen_at", "Last Seen"),
            ("ip_address", "IP"),
            ("is_active", "Active"),
        ):
            self.tree.heading(column, text=title)
            self.tree.column(column, width=140, anchor="w")
        self.tree.grid(row=1, column=0, sticky="nsew")

    def load_data(self, sessions: list[dict]) -> None:
        for item in self.tree.get_children():
            self.tree.delete(item)

        for session in sessions:
            self.tree.insert(
                "",
                "end",
                values=(
                    session.get("created_at", ""),
                    session.get("expires_at", ""),
                    session.get("last_seen_at") or "-",
                    session.get("ip_address") or "-",
                    "Yes" if session.get("is_active") else "No",
                ),
            )
