# Rebuild build/web and deploy hosting (production PWA). Run after Saints UI changes.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

Write-Host "flutter build web..." -ForegroundColor Cyan
flutter build web
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "firebase deploy --only hosting" -ForegroundColor Cyan
firebase deploy --only hosting
