$ErrorActionPreference = "Stop"

$root = "C:\Fuel Management System"
$python = "$root\venv\Scripts\python.exe"
$outLog = "$root\uvicorn_8012.out.log"
$errLog = "$root\uvicorn_8012.err.log"

Get-CimInstance Win32_Process |
  Where-Object {
    $_.CommandLine -and $_.CommandLine -like "*run_local_server.py*"
  } |
  ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
  }

Start-Sleep -Seconds 1

Start-Process `
  -FilePath $python `
  -ArgumentList ".\run_local_server.py" `
  -WorkingDirectory $root `
  -RedirectStandardOutput $outLog `
  -RedirectStandardError $errLog `
  -WindowStyle Hidden

$healthOk = $false

for ($i = 0; $i -lt 10; $i++) {
  Start-Sleep -Seconds 1
  try {
    $health = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8012/health -TimeoutSec 3
    $healthOk = $true
    break
  } catch {
  }
}

if ($healthOk) {
  Write-Host "Backend restarted successfully"
  Write-Host $health.Content
  Start-Process powershell -ArgumentList "-NoExit", "-Command", "Get-Content '$outLog' -Wait"
} else {
  Write-Host "Backend start attempted, but health check failed after retries"
  Start-Process powershell -ArgumentList "-NoExit", "-Command", "Get-Content '$errLog' -Wait"
}
