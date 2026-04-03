from __future__ import annotations

import tkinter as tk
from tkinter import ttk


class LoginView(ttk.Frame):
    def __init__(self, master: tk.Misc, on_login, default_url: str):
        super().__init__(master, padding=24)
        self.on_login = on_login
        self.columnconfigure(0, weight=1)

        container = ttk.Frame(self, padding=24)
        container.grid(sticky="nsew")
        container.columnconfigure(1, weight=1)

        ttk.Label(container, text="PPMS Desktop", font=("Segoe UI", 20, "bold")).grid(
            row=0, column=0, columnspan=2, sticky="w", pady=(0, 8)
        )
        ttk.Label(
            container,
            text="Connect this desktop client to your local PPMS backend and sign in.",
        ).grid(row=1, column=0, columnspan=2, sticky="w", pady=(0, 20))

        ttk.Label(container, text="Backend URL").grid(row=2, column=0, sticky="w", pady=4)
        self.base_url_var = tk.StringVar(value=default_url)
        ttk.Entry(container, textvariable=self.base_url_var, width=48).grid(row=2, column=1, sticky="ew", pady=4)

        ttk.Label(container, text="Username").grid(row=3, column=0, sticky="w", pady=4)
        self.username_var = tk.StringVar()
        self.username_entry = ttk.Entry(container, textvariable=self.username_var, width=32)
        self.username_entry.grid(row=3, column=1, sticky="ew", pady=4)

        ttk.Label(container, text="Password").grid(row=4, column=0, sticky="w", pady=4)
        self.password_var = tk.StringVar()
        password_entry = ttk.Entry(container, textvariable=self.password_var, show="*", width=32)
        password_entry.grid(row=4, column=1, sticky="ew", pady=4)

        self.error_var = tk.StringVar(value="")
        ttk.Label(container, textvariable=self.error_var, foreground="#a61c1c").grid(
            row=5, column=0, columnspan=2, sticky="w", pady=(8, 8)
        )

        self.status_var = tk.StringVar(value="Ready")
        ttk.Label(container, textvariable=self.status_var).grid(row=6, column=0, sticky="w", pady=(4, 0))

        ttk.Button(container, text="Sign In", command=self._submit).grid(
            row=6, column=1, sticky="e", pady=(12, 0)
        )

        self.username_entry.focus_set()
        self.bind_all("<Return>", lambda _event: self._submit())

    def _submit(self) -> None:
        self.error_var.set("")
        self.status_var.set("Signing in...")
        self.update_idletasks()
        self.on_login(
            self.base_url_var.get().strip(),
            self.username_var.get().strip(),
            self.password_var.get(),
        )

    def set_error(self, message: str) -> None:
        self.status_var.set("Sign-in failed")
        self.error_var.set(message)
