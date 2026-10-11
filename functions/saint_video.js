const { getAuth } = require("firebase-admin/auth");
const { getSaintMediaBucket } = require("./saint_media_bucket");
const { getFirestore } = require("firebase-admin/firestore");
const { randomUUID } = require("crypto");
const { isFoundationAdminEmail } = require("./admin_config");

const MAX_BYTES = 12 * 1024 * 1024;

function buildDownloadUrl(bucketName, objectPath, token) {
  const encoded = encodeURIComponent(objectPath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}?alt=media&token=${token}`;
}

/** Firebase download token from object metadata (first token if comma-separated). */
function readDownloadToken(metadata) {
  let token = metadata?.metadata?.firebaseStorageDownloadTokens;
  if (typeof token !== "string" || token.length === 0) return null;
  if (token.includes(",")) token = token.split(",")[0].trim();
  return token || null;
}

async function isSuperAdmin(uid, email) {
  if (isFoundationAdminEmail(email)) return true;
  const snap = await getFirestore().doc(`platformAdmins/${uid}`).get();
  return snap.exists;
}

const FEAST_VIDEO_PATH =
  /^Saints\/[0-9]{4}-[0-9]{2}-[0-9]{2}-[A-Za-z0-9._-]+\/(portrait|landscape|Archangels_Feast)\.mp4$/;
const LEGACY_SEGMENT_PATH =
  /^saints\/[a-z0-9][a-z0-9-]*\/seg-[1-8]\.mp4$/;

function registerSaintVideoFunctions(exports) {
  const { onRequest } = require("firebase-functions/v2/https");

  /**
   * GET ?path=Saints/2026-09-23-pio-pietrelcina/portrait.mp4
   * Streams feast / legacy saint mp4 (Range-aware) for web/PWA playback.
   */
  exports.streamSaintVideo = onRequest(
    {
      cors: true,
      timeoutSeconds: 300,
      memory: "512MiB",
      invoker: "public",
    },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "GET") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      const path =
        typeof req.query.path === "string" ? req.query.path.trim() : "";
      if (
        !FEAST_VIDEO_PATH.test(path) &&
        !LEGACY_SEGMENT_PATH.test(path)
      ) {
        res.status(400).json({ error: "Invalid saint video path" });
        return;
      }

      try {
        const bucket = getSaintMediaBucket();
        const file = bucket.file(path);
        const [exists] = await file.exists();
        if (!exists) {
          res.status(404).json({ error: "Video not found" });
          return;
        }

        const [metadata] = await file.getMetadata();
        const fileSize = Number(metadata.size || 0);
        const storedType = metadata.contentType || "";
        const contentType =
          path.endsWith(".mp4")
            ? "video/mp4"
            : storedType.startsWith("video/")
              ? storedType
              : "video/mp4";

        const range = req.headers.range;

        // Web iframes often GET without Range; large files exceed CF response limits.
        // Redirect to Storage (same token URLs as Firestore) for byte-range playback there.
        if (!range) {
          const token = readDownloadToken(metadata);
          if (token) {
            const downloadUrl = buildDownloadUrl(bucket.name, path, token);
            res.redirect(302, downloadUrl);
            return;
          }
        }

        if (range && fileSize > 0) {
          const parts = range.replace(/bytes=/, "").split("-");
          const start = parseInt(parts[0], 10);
          const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
          if (Number.isNaN(start) || start >= fileSize) {
            res
              .status(416)
              .set("Content-Range", `bytes */${fileSize}`)
              .end();
            return;
          }
          const safeEnd = Math.min(end, fileSize - 1);
          const chunkSize = safeEnd - start + 1;
          res.status(206);
          res.set({
            "Content-Range": `bytes ${start}-${safeEnd}/${fileSize}`,
            "Accept-Ranges": "bytes",
            "Content-Length": chunkSize,
            "Content-Type": contentType,
            "Cache-Control": "public, max-age=3600",
          });
          file.createReadStream({ start, end: safeEnd }).pipe(res);
          return;
        }

        res.set({
          "Content-Length": fileSize,
          "Content-Type": contentType,
          "Accept-Ranges": "bytes",
          "Cache-Control": "public, max-age=3600",
        });
        file.createReadStream().pipe(res);
      } catch (err) {
        console.error("streamSaintVideo error:", err);
        if (!res.headersSent) {
          res.status(500).json({ error: "Could not stream video" });
        }
      }
    }
  );

  /**
   * POST JSON: { saintId, order, contentType, dataBase64 }
   * Writes saints/{saintId}/seg-{n}.mp4 — Overall Admin only.
   */
  exports.uploadSaintVideo = onRequest(
    {
      cors: true,
      timeoutSeconds: 180,
      memory: "1GiB",
      invoker: "public",
    },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      const authHeader = req.headers.authorization || "";
      const idToken = authHeader.startsWith("Bearer ")
        ? authHeader.slice(7).trim()
        : "";
      if (!idToken) {
        res.status(401).json({ error: "Sign in required" });
        return;
      }

      let uid;
      let email;
      try {
        const decoded = await getAuth().verifyIdToken(idToken);
        uid = decoded.uid;
        email = decoded.email || "";
      } catch (err) {
        console.error("uploadSaintVideo auth error:", err);
        res.status(401).json({ error: "Invalid or expired sign-in." });
        return;
      }

      if (!(await isSuperAdmin(uid, email))) {
        res.status(403).json({ error: "Overall Admin access required." });
        return;
      }

      const saintId =
        typeof req.body?.saintId === "string" ? req.body.saintId.trim() : "";
      if (
        saintId.length < 2 ||
        saintId.length > 80 ||
        !/^[a-z0-9][a-z0-9-]*[a-z0-9]$/.test(saintId)
      ) {
        res.status(400).json({ error: "Invalid saint id." });
        return;
      }

      const order = Number(req.body?.order);
      if (!Number.isInteger(order) || order < 1 || order > 8) {
        res.status(400).json({ error: "Segment order must be 1–8." });
        return;
      }

      const dataBase64 = req.body?.dataBase64;
      if (!dataBase64 || typeof dataBase64 !== "string") {
        res.status(400).json({ error: "Missing video data" });
        return;
      }

      let buffer;
      try {
        buffer = Buffer.from(dataBase64, "base64");
      } catch (err) {
        res.status(400).json({ error: "Invalid video data" });
        return;
      }
      if (buffer.length === 0) {
        res.status(400).json({ error: "Empty video file" });
        return;
      }
      if (buffer.length > MAX_BYTES) {
        res.status(400).json({ error: "Each clip must be under 12 MB." });
        return;
      }

      const saintDoc = await getFirestore().doc(`saints/${saintId}`).get();
      if (!saintDoc.exists) {
        res.status(404).json({ error: "Save the saint entry before uploading clips." });
        return;
      }

      try {
        const bucket = getSaintMediaBucket();
        const objectPath = `saints/${saintId}/seg-${order}.mp4`;
        const file = bucket.file(objectPath);
        const downloadToken = randomUUID();
        await file.save(buffer, {
          metadata: {
            contentType: "video/mp4",
            cacheControl: "public,max-age=3600",
            metadata: {
              firebaseStorageDownloadTokens: downloadToken,
            },
          },
        });
        const downloadUrl = buildDownloadUrl(bucket.name, objectPath, downloadToken);
        res.status(200).json({ downloadUrl, path: objectPath });
      } catch (err) {
        console.error("uploadSaintVideo storage error:", err);
        res.status(500).json({ error: "Could not save the video clip." });
      }
    }
  );
}

module.exports = { registerSaintVideoFunctions };
