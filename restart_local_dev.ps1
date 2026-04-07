[CmdletBinding()]
param(
    [switch]$SkipBackend,
    [switch]$SkipBackendLogs,
    [switch]$SkipSupportConsole,
    [switch]$SkipFlutter,
    [string]$ApiBaseUrl = "http://127.0.0.1:8012",
    [int]$SupportConsolePort = 3000
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonExe = Join-Path $RepoRoot "venv\Scripts\python.exe"
$SupportConsoleDir = Join-Path $RepoRoot "support_console"
$FlutterDir = Join-Path $RepoRoot "ppms_flutter"

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

Write-Host "Restarting PPMS local development stack from $RepoRoot"

if (-not $SkipSupportConsole) {
    Stop-ProcessByCommandLineMatch -Label "support console" -Needle $SupportConsoleDir
    Stop-PortListener -Port $SupportConsolePort
}

if (-not $SkipFlutter) {
    Stop-ProcessByCommandLineMatch -Label "Flutter" -Needle $FlutterDir
    Stop-ProcessByCommandLineMatch -Label "Flutter PPMS Windows app" -Needle "ppms_flutter.exe"
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
}

if (-not $SkipSupportConsole) {
    Write-Host "Starting support console in a new window..."
    Start-DevWindow -Title "PPMS Support Console" -WorkingDirectory $SupportConsoleDir -Command "npm.cmd run dev"
}

if (-not $SkipFlutter) {
    Write-Host "Starting Flutter Windows app in a new window..."
    Start-DevWindow -Title "PPMS Flutter" -WorkingDirectory $FlutterDir -Command "flutter run -d windows --dart-define=PPMS_API_BASE_URL=$ApiBaseUrl"
}

Write-Host "Restart command finished. Backend health: $ApiBaseUrl/health"
