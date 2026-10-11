/**
 * Print Firebase Storage HTTPS download URL for a bucket object (for seed env vars).
 *
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "...\adminsdk.json"
 *   node functions/scripts/storage_download_url.js Saints/2026-09-29-Archangels/landscape.mp4
 *
 * Accepts gs://bucket/path or plain object path.
 */
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const DEFAULT_BUCKET = "wwjd-di-e36ce.firebasestorage.app";

function resolveProjectId() {
  try {
    const raw = fs.readFileSync(
      path.join(__dirname, "..", "..", ".firebaserc"),
      "utf8"
    );
    return JSON.parse(raw)?.projects?.default || "wwjd-di-e36ce";
  } catch (_) {
    return "wwjd-di-e36ce";
  }
}

function parseObjectPath(arg) {
  const trimmed = (arg || "").trim();
  if (!trimmed) return null;
  if (trimmed.startsWith("gs://")) {
    const without = trimmed.slice("gs://".length);
    const slash = without.indexOf("/");
    if (slash <= 0) return null;
    return {
      bucket: without.slice(0, slash),
      objectPath: without.slice(slash + 1),
    };
  }
  return { bucket: DEFAULT_BUCKET, objectPath: trimmed.replace(/^\/+/, "") };
}

function buildDownloadUrl(bucketName, objectPath, token) {
  const encoded = encodeURIComponent(objectPath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}?alt=media&token=${token}`;
}

async function main() {
  const arg = process.argv[2];
  const parsed = parseObjectPath(arg);
  if (!parsed) {
    console.error(
      "Usage: node functions/scripts/storage_download_url.js <object-path|gs://...>"
    );
    process.exit(1);
  }

  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId: resolveProjectId() });
  }

  const bucket = admin.storage().bucket(parsed.bucket);
  const file = bucket.file(parsed.objectPath);
  const [exists] = await file.exists();
  if (!exists) {
    console.error("Object not found: gs://" + parsed.bucket + "/" + parsed.objectPath);
    process.exit(1);
  }

  const [meta] = await file.getMetadata();
  let token = meta.metadata?.firebaseStorageDownloadTokens;
  if (typeof token === "string" && token.includes(",")) {
    token = token.split(",")[0].trim();
  }
  if (!token) {
    console.error(
      "No download token on object. In Firebase Console open the file and use Copy download URL."
    );
    process.exit(1);
  }

  const url = buildDownloadUrl(parsed.bucket, parsed.objectPath, token);
  console.log(url);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
