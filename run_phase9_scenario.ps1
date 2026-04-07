$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Join-Path $repoRoot "venv\Scripts\python.exe"

if (-not (Test-Path $python)) {
    $python = "python"
}

& $python (Join-Path $repoRoot "scripts\run_phase9_scenario.py") @args
