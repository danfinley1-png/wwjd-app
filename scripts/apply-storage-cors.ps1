# Apply Firebase Storage CORS so localhost/web uploads work (fixes "Failed to fetch").
# Requires Google Cloud SDK: https://cloud.google.com/sdk/docs/install
#
# Usage (from project root):
#   gcloud storage buckets update gs://wwjd-di-e36ce.firebasestorage.app --cors-file=storage.cors.json
#
# Or with legacy gsutil:
#   gsutil cors set storage.cors.json gs://wwjd-di-e36ce.firebasestorage.app
#
# Verify:
#   gcloud storage buckets describe gs://wwjd-di-e36ce.firebasestorage.app --format="json(cors)"

Write-Host "Applying Storage CORS from storage.cors.json ..."
gcloud storage buckets update gs://wwjd-di-e36ce.firebasestorage.app --cors-file=storage.cors.json
if ($LASTEXITCODE -eq 0) {
  Write-Host "CORS applied. Hard-refresh your browser and retry profile photo upload."
} else {
  Write-Host "If gcloud is not installed, use Firebase/Google Cloud console or install gcloud first."
}
