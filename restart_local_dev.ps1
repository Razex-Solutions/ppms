[CmdletBinding()]
param(
    [switch]$SkipBackend,
    [switch]$SkipBackendLogs,
    [switch]$SkipFlutter,
    [switch]$SkipTenantPrep,
    [string]$ApiBaseUrl = "http://127.0.0.1:8012"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonExe = Join-Path $RepoRoot "venv\Scripts\python.exe"

function Stop-PortListener {
    param([int]$Port)

    $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    foreach ($processId in ($connections | Select-Object -ExpandProperty OwningProcess -Unique)) {
        if ($processId -and $processId -ne $PID) {
            Write-Host "Stopping listener on port $Port (PID $processId)..."
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        }
    }
}

function Stop-ProcessByCommandLineMatch {
    param(
        [string]$Label,
        [string]$Needle
    )

    $escapedNeedle = [regex]::Escape($Needle)
    $matches = Get-CimInstance Win32_Process |
        Where-Object {
            $_.ProcessId -ne $PID -and
            $_.CommandLine -and
            $_.CommandLine -match $escapedNeedle
        }

    foreach ($process in $matches) {
        Write-Host "Stopping $Label process PID $($process.ProcessId)..."
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Start-DevWindow {
    param(
        [string]$Title,
        [string]$WorkingDirectory,
        [string]$Command
    )

    $escapedTitle = $Title.Replace("'", "''")
    $escapedDirectory = $WorkingDirectory.Replace("'", "''")
    $escapedCommand = $Command.Replace("'", "''")
    $script = "& { `$Host.UI.RawUI.WindowTitle = '$escapedTitle'; Set-Location -LiteralPath '$escapedDirectory'; $escapedCommand }"
    Start-Process powershell.exe -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $script) -WorkingDirectory $WorkingDirectory
}

Write-Host "Restarting PPMS local backend stack from $RepoRoot"

if (-not $SkipFlutter) {
    Stop-ProcessByCommandLineMatch -Label "old Flutter PPMS Windows app" -Needle "ppms_flutter.exe"
    Stop-ProcessByCommandLineMatch -Label "tenant Flutter PPMS Windows app" -Needle "ppms_tenant_flutter.exe"
}

if (-not $SkipBackend) {
    if (-not $SkipBackendLogs) {
        Stop-ProcessByCommandLineMatch -Label "backend log monitor" -Needle "watch_backend_logs.ps1"
    }

    if (-not (Test-Path -LiteralPath $PythonExe)) {
        throw "Python virtual environment not found at $PythonExe"
    }
    Write-Host "Restarting backend on $ApiBaseUrl..."
    & $PythonExe (Join-Path $RepoRoot "run_local_server.py")

    if (-not $SkipBackendLogs) {
        Write-Host "Opening backend log monitor in a new window..."
        Start-DevWindow -Title "PPMS Backend Logs" -WorkingDirectory $RepoRoot -Command ".\watch_backend_logs.ps1 -HealthUrl $ApiBaseUrl/health"
    }

    if (-not $SkipTenantPrep) {
        Write-Host "Preparing Phase 9 tenant test users..."
        & $PythonExe (Join-Path $RepoRoot "scripts\ensure_phase9_tenant.py")
    }
}

if (-not $SkipFlutter) {
    Write-Host "Flutter launch skipped because no Flutter app folder is currently present in the repository."
}

Write-Host "Restart command finished. Backend health: $ApiBaseUrl/health"
