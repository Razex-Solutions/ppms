$ErrorActionPreference = "Stop"

$root = "C:\Fuel Management System"
$playwrightDir = Join-Path $root "playwright"

Write-Host "Restarting backend..."
powershell -ExecutionPolicy Bypass -File (Join-Path $root "restart_backend.ps1")

Write-Host "Building Flutter web app..."
pushd (Join-Path $root "ppms_tenant_flutter")
flutter build web --release --dart-define=PPMS_API_BASE_URL=http://127.0.0.1:8012 --dart-define=PPMS_E2E_MODE=true
popd

if (-not (Test-Path (Join-Path $playwrightDir "node_modules"))) {
  Write-Host "Installing Playwright dependencies..."
  & npm.cmd install --prefix $playwrightDir
}

Write-Host "Installing Chromium browser if needed..."
& "$playwrightDir\node_modules\.bin\playwright.cmd" install chromium

Write-Host "Running StationAdmin UI smoke..."
& npm.cmd --prefix $playwrightDir run test:station-admin
