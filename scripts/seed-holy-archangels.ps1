# Resolves gs:// or https Storage URLs and writes saints/holy-archangels.
# See tool/feast_saint_firestore_urls.md

$ErrorActionPreference = "Stop"

if (-not $env:GOOGLE_APPLICATION_CREDENTIALS) {
  Write-Error "Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON."
}

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $root
try {
  node functions/scripts/seed_holy_archangels.js
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
