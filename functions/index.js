const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const { registerInstitutionalFunctions } = require("./institutional");
const { registerInstitutionalEmailFunctions } = require("./institutional_emails");
const { registerUsageReportFunctions } = require("./usage_report");
const { registerUserDirectoryFunctions } = require("./user_directory");
const { registerQuestionThemeFunctions } = require("./question_theme");
const { registerNearbyParishes } = require("./nearby_parishes");
const { registerOrgLogoFunctions } = require("./org_logo");
const { registerSaintVideoFunctions } = require("./saint_video");
const { randomUUID } = require("crypto");
const { consumeChatQuota } = require("./chat_quota");

const xaiApiKey = defineSecret("XAI_API_KEY");

if (getApps().length === 0) {
  initializeApp();
}

const MAX_BYTES = 5 * 1024 * 1024;

function buildDownloadUrl(bucketName, objectPath, token) {
  const encoded = encodeURIComponent(objectPath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}?alt=media&token=${token}`;
}

const CHAT_MAX_BODY_BYTES = 256 * 1024;
const CHAT_MAX_MESSAGES = 32;
/** WWJD system prompt is large; only cap user/assistant per message. */
const CHAT_MAX_SYSTEM_CHARS = 120_000;
const CHAT_MAX_USER_CHARS = 32_000;
const CHAT_MAX_OTHER_MESSAGE_CHARS = 16_000;
const CHAT_MAX_TOTAL_CHARS = 200_000;
const CHAT_MAX_TOKENS = 1400;

function chatMessageCharLimit(role) {
  if (role === "system") return CHAT_MAX_SYSTEM_CHARS;
  if (role === "user") return CHAT_MAX_USER_CHARS;
  return CHAT_MAX_OTHER_MESSAGE_CHARS;
}

function readBearerIdToken(req) {
  const authHeader = req.headers.authorization || "";
  return authHeader.startsWith("Bearer ") ? authHeader.slice(7).trim() : "";
}

async function requireAuth(req, res) {
  const idToken = readBearerIdToken(req);
  if (!idToken) {
    res.status(401).json({ error: "Sign in required" });
    return null;
  }
  try {
    return await getAuth().verifyIdToken(idToken);
  } catch (err) {
    console.error("chatCompletions auth error:", err);
    res.status(401).json({
      error: "Invalid or expired sign-in. Please sign in again.",
    });
    return null;
  }
}

function validateChatPayload(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return "Invalid request body";
  }
  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return "messages array is required";
  }
  if (messages.length > CHAT_MAX_MESSAGES) {
    return "Too many messages";
  }
  let totalChars = 0;
  for (const msg of messages) {
    if (!msg || typeof msg !== "object") {
      return "Invalid message";
    }
    const content = msg.content;
    if (typeof content !== "string") {
      return "Invalid message content";
    }
    const role = typeof msg.role === "string" ? msg.role : "";
    const limit = chatMessageCharLimit(role);
    if (content.length > limit) {
      return "Message too long";
    }
    totalChars += content.length;
  }
  if (totalChars > CHAT_MAX_TOTAL_CHARS) {
    return "Prompt too long";
  }
  return null;
}

function sanitizeChatPayload(body) {
  const out = { ...body };
  const maxTokens = Number(out.max_tokens);
  if (!Number.isFinite(maxTokens) || maxTokens > CHAT_MAX_TOKENS) {
    out.max_tokens = CHAT_MAX_TOKENS;
  }
  return out;
}

/**
 * Proxies xAI chat completions (Firebase Auth required).
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

    const contentLength = parseInt(req.headers["content-length"] || "0", 10);
    if (contentLength > CHAT_MAX_BODY_BYTES) {
      res.status(413).json({ error: "Request too large" });
      return;
    }

    const decoded = await requireAuth(req, res);
    if (!decoded) {
      return;
    }

    const validationError = validateChatPayload(req.body);
    if (validationError) {
      res.status(400).json({ error: validationError });
      return;
    }

    const quotaResult = await consumeChatQuota(decoded);
    if (!quotaResult.ok) {
      res.status(quotaResult.status).json(quotaResult.body);
      return;
    }

    const key = xaiApiKey.value();
    if (!key) {
      res.status(500).json({ error: "XAI_API_KEY secret is not configured" });
      return;
    }

    const payload = sanitizeChatPayload(req.body);

    try {
      const upstream = await fetch("https://api.x.ai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify(payload),
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
registerUserDirectoryFunctions(exports);
registerQuestionThemeFunctions(exports);
registerNearbyParishes(exports);
registerOrgLogoFunctions(exports);
registerSaintVideoFunctions(exports);
