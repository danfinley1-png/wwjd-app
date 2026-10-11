# Merge CLAVER_* / PIO_* / ARCHANGELS_* download URLs into Firestore (partial update OK).
$ErrorActionPreference = "Stop"

if (-not $env:GOOGLE_APPLICATION_CREDENTIALS) {
  Write-Host @"

Set your real service account JSON (not the placeholder path):

  `$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\wwjd-di-e36ce-firebase-adminsdk.json"

Download from:
  https://console.firebase.google.com/project/wwjd-di-e36ce/settings/serviceaccounts/adminsdk

Poster URLs must be FULL https links — copy from Firebase Console Storage (poster.jpg).
Do not use ... in the URL.

"@ -ForegroundColor Yellow
  exit 1
}

if (-not (Test-Path -LiteralPath $env:GOOGLE_APPLICATION_CREDENTIALS)) {
  Write-Error "Service account file not found: $($env:GOOGLE_APPLICATION_CREDENTIALS)"
}

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $root
try {
  node functions/scripts/patch_feast_saint_urls.js
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
