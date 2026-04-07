$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

& ".\venv\Scripts\python.exe" ".\scripts\ensure_phase9_tenant.py"
