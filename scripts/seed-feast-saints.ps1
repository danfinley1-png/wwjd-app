# Seeds feast saints in Firestore (peter-claver, pio-pietrelcina, holy-archangels, faustina).
# Does NOT require gcloud — only a Firebase service account key JSON.
#
# One-time setup:
#   1. Firebase Console → Project settings → Service accounts
#   2. "Generate new private key" → save outside the repo (e.g. Downloads)
#   3. In this PowerShell session:
#        $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\danfi\Downloads\wwjd-di-e36ce-firebase-adminsdk-xxxxx.json"
#   4. For Archangels only: .\\scripts\\seed-holy-archangels.ps1 (ARCHANGELS_VIDEO_* env vars)
#      See tool/feast_saint_firestore_urls.md
#   5. Faustina uses the gs:// paths below unless FAUSTINA_* is already set.
#      The seed writes https download URLs only and refuses missing, gs://, or PASTE.
#   6. Run: .\scripts\seed-feast-saints.ps1

$ErrorActionPreference = "Stop"

if (-not $env:GOOGLE_APPLICATION_CREDENTIALS) {
  Write-Host @"

Missing GOOGLE_APPLICATION_CREDENTIALS.

Without Google Cloud SDK (gcloud), use a service account key:

  1. Open https://console.firebase.google.com/project/wwjd-di-e36ce/settings/serviceaccounts/adminsdk
  2. Generate new private key (JSON file)
  3. Set:
       `$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\that-file.json"

Optional (if you install Cloud SDK later):
  gcloud auth application-default login
  gcloud config set project wwjd-di-e36ce

Then set env vars and run this script again (Archangels: seed-holy-archangels.ps1).

"@
  exit 1
}

if (-not (Test-Path -LiteralPath $env:GOOGLE_APPLICATION_CREDENTIALS)) {
  Write-Error "GOOGLE_APPLICATION_CREDENTIALS file not found: $($env:GOOGLE_APPLICATION_CREDENTIALS)"
}

# St. Faustina — Storage inputs. Seed resolves these to download URLs and
# refuses the write if any URL is missing, remains gs://, or contains PASTE.
if (-not $env:FAUSTINA_VIDEO_LANDSCAPE_URL) {
  $env:FAUSTINA_VIDEO_LANDSCAPE_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/landscape.mp4"
}
if (-not $env:FAUSTINA_VIDEO_PORTRAIT_URL) {
  $env:FAUSTINA_VIDEO_PORTRAIT_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/portrait.mp4"
}
if (-not $env:FAUSTINA_POSTER_PORTRAIT_URL) {
  $env:FAUSTINA_POSTER_PORTRAIT_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/poster.png"
}

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $root
try {
  node functions/scripts/seed_feast_saints.js
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
