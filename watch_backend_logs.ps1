[CmdletBinding()]
param(
    [string]$HealthUrl = "http://127.0.0.1:8012/health",
    [int]$Tail = 80
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutLog = Join-Path $RepoRoot "uvicorn_8012.out.log"
$ErrLog = Join-Path $RepoRoot "uvicorn_8012.err.log"

Write-Host "PPMS backend log monitor"
Write-Host "Health: $HealthUrl"
Write-Host "stdout: $OutLog"
Write-Host "stderr: $ErrLog"
Write-Host ""

try {
    $health = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5
    Write-Host "Current health response:"
    Write-Host $health.Content
} catch {
    Write-Host "Health check failed: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Showing last $Tail backend lines, then live updates. Look for HTTP status codes such as 200, 400, 403, and 500."
Write-Host "Press Ctrl+C in this window to stop watching logs."
Write-Host ""

foreach ($path in @($OutLog, $ErrLog)) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType File -Path $path -Force | Out-Null
    }
}

Get-Content -Path $OutLog, $ErrLog -Tail $Tail -Wait
