$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

& .\venv\Scripts\python.exe .\scripts\run_phase9_tenant_ui_api_smoke.py
