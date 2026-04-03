from __future__ import annotations

import tkinter as tk
from tkinter import ttk


class PlaceholderView(ttk.Frame):
    def __init__(self, master: tk.Misc, title: str, message: str):
        super().__init__(master, padding=16)
        ttk.Label(self, text=title, font=("Segoe UI", 16, "bold")).grid(row=0, column=0, sticky="w", pady=(0, 12))
        ttk.Label(self, text=message, wraplength=820, justify="left").grid(row=1, column=0, sticky="w")
