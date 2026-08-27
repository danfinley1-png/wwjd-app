const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const { registerInstitutionalFunctions } = require("./institutional");
const { registerInstitutionalEmailFunctions } = require("./institutional_emails");
const { registerUsageReportFunctions } = require("./usage_report");
const { registerNearbyParishes } = require("./nearby_parishes");
const { registerOrgLogoFunctions } = require("./org_logo");
const { randomUUID } = require("crypto");

const xaiApiKey = defineSecret("XAI_API_KEY");

if (getApps().length === 0) {
  initializeApp();
}

const MAX_BYTES = 5 * 1024 * 1024;

function buildDownloadUrl(bucketName, objectPath, token) {
  const encoded = encodeURIComponent(objectPath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}?alt=media&token=${token}`;
}

/**
 * Proxies xAI chat completions for the Flutter web app (avoids browser CORS).
 * Hosting rewrite: /api/chat -> this function.
 */
exports.chatCompletions = onRequest(
  {
    cors: true,
    secrets: [xaiApiKey],
    timeoutSeconds: 120,
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

    const key = xaiApiKey.value();
    if (!key) {
      res.status(500).json({ error: "XAI_API_KEY secret is not configured" });
      return;
    }

    try {
      const upstream = await fetch("https://api.x.ai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify(req.body),
      });

      const body = await upstream.text();
      res.status(upstream.status);
      res.set("Content-Type", "application/json");
      res.send(body);
    } catch (err) {
      console.error("chatCompletions proxy error:", err);
      res.status(502).json({ error: "Upstream AI request failed" });
    }
  }
);

/**
 * Uploads profile photos server-side (avoids Firebase Storage CORS on web/Edge).
 * Hosting rewrite: /api/profile-photo -> this function.
 *
 * GET  — returns profile image bytes for the signed-in user.
 * POST JSON: { contentType: "image/jpeg", dataBase64: "..." }
 * Header: Authorization: Bearer <Firebase ID token>
 */
exports.uploadProfilePhoto = onRequest(
  {
    cors: true,
    timeoutSeconds: 60,
    invoker: "public",
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
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
    try {
      const decoded = await getAuth().verifyIdToken(idToken);
      uid = decoded.uid;
      if (decoded.firebase?.sign_in_provider === "anonymous") {
        res.status(403).json({
          error: "Create an account (not guest) to save a profile photo.",
        });
        return;
      }
    } catch (err) {
      console.error("uploadProfilePhoto auth error:", err);
      res.status(401).json({
        error: "Invalid or expired sign-in. Please sign in again.",
      });
      return;
    }

    if (req.method === "GET") {
      try {
        const bucket = getStorage().bucket();
        const objectPath = `users/${uid}/profile.jpg`;
        const file = bucket.file(objectPath);
        const [exists] = await file.exists();
        if (!exists) {
          res.status(404).json({ error: "No profile photo" });
          return;
        }
        const [metadata] = await file.getMetadata();
        const contentType =
          metadata.contentType && metadata.contentType.startsWith("image/")
            ? metadata.contentType
            : "image/jpeg";
        const [buffer] = await file.download();
        res.set("Content-Type", contentType);
        res.set("Cache-Control", "private, max-age=300");
        res.status(200).send(buffer);
      } catch (err) {
        console.error("uploadProfilePhoto GET error:", err);
        res.status(500).json({ error: "Could not load profile photo" });
      }
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const contentType =
      typeof req.body?.contentType === "string" && req.body.contentType.startsWith("image/")
        ? req.body.contentType
        : "image/jpeg";
    const dataBase64 = req.body?.dataBase64;
    if (!dataBase64 || typeof dataBase64 !== "string") {
      res.status(400).json({ error: "Missing image data" });
      return;
    }

    let buffer;
    try {
      buffer = Buffer.from(dataBase64, "base64");
    } catch (err) {
      res.status(400).json({ error: "Invalid image data" });
      return;
    }

    if (buffer.length === 0) {
      res.status(400).json({ error: "Empty image file" });
      return;
    }
    if (buffer.length > MAX_BYTES) {
      res.status(400).json({ error: "Photo is too large. Maximum size is 5 MB." });
      return;
    }

    try {
      const bucket = getStorage().bucket();
      const objectPath = `users/${uid}/profile.jpg`;
      const file = bucket.file(objectPath);
      const downloadToken = randomUUID();

      await file.save(buffer, {
        metadata: {
          contentType,
          cacheControl: "public,max-age=3600",
          metadata: {
            firebaseStorageDownloadTokens: downloadToken,
          },
        },
      });

      const downloadUrl = buildDownloadUrl(bucket.name, objectPath, downloadToken);
      res.status(200).json({ downloadUrl });
    } catch (err) {
      console.error("uploadProfilePhoto storage error:", err);
      res.status(500).json({ error: "Could not save profile photo" });
    }
  }
);

registerInstitutionalFunctions(exports);
registerInstitutionalEmailFunctions(exports);
registerUsageReportFunctions(exports);
registerNearbyParishes(exports);
registerOrgLogoFunctions(exports);
