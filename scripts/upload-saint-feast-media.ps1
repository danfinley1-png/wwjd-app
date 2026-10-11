# Upload feast-day saint videos to Firebase Storage (capital S: Saints/...).
# Requires: Google Cloud SDK (gcloud auth login, gcloud config set project wwjd-di-e36ce)
#
# Usage:
#   .\scripts\upload-saint-feast-media.ps1 -LocalPortrait "C:\Users\danfi\Saints\...\pio-9x16.mp4" -SaintKey pio-pietrelcina -SortDate 2026-09-23
# Optional: -LocalLandscape, -LocalPoster

param(
  [Parameter(Mandatory = $true)]
  [string]$LocalPortrait,
  [Parameter(Mandatory = $true)]
  [string]$SaintKey,
  [Parameter(Mandatory = $true)]
  [string]$SortDate,
  [string]$LocalLandscape = "",
  [string]$LocalPoster = ""
)

$Bucket = "gs://wwjd-di-e36ce.firebasestorage.app"
$Prefix = "Saints/$SortDate-$SaintKey"

if (-not (Test-Path -LiteralPath $LocalPortrait)) {
  Write-Error "Portrait file not found: $LocalPortrait"
  exit 1
}

gcloud storage cp --content-type="video/mp4" $LocalPortrait "$Bucket/$Prefix/portrait.mp4"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($LocalLandscape -ne "" -and (Test-Path -LiteralPath $LocalLandscape)) {
  gcloud storage cp --content-type="video/mp4" $LocalLandscape "$Bucket/$Prefix/landscape.mp4"
}

if ($LocalPoster -ne "" -and (Test-Path -LiteralPath $LocalPoster)) {
  gcloud storage cp --content-type="image/jpeg" $LocalPoster "$Bucket/$Prefix/poster.jpg"
}

Write-Host "Uploaded to $Bucket/$Prefix/"
Write-Host "In Firebase Console → Storage, open each file and copy the download URL for seed_feast_saints.js env vars."
