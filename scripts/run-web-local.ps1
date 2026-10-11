# Run WWJD-DI from SOURCE (not stale build/web). Use this for Saints work.
# Chrome opens with path URLs; Firebase Hosting rewrites are NOT available unless emulators run.
#
# For /api/stream-saint-video on localhost, the app uses the Cloud Function URL automatically.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

Write-Host "Starting flutter run -d chrome (compiles lib/, not build/web cache)..." -ForegroundColor Cyan
Write-Host "On Saints tab you should see: Saints build: saints-2026-03-22-v3" -ForegroundColor Yellow
flutter run -d chrome
