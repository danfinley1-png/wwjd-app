const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { randomUUID } = require("crypto");
const { isFoundationAdminEmail } = require("./admin_config");

const MAX_BYTES = 5 * 1024 * 1024;

function buildDownloadUrl(bucketName, objectPath, token) {
  const encoded = encodeURIComponent(objectPath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}?alt=media&token=${token}`;
}

async function canSetOrgLogo(uid, email, orgId) {
  if (!orgId || typeof orgId !== "string") return false;
  if (isFoundationAdminEmail(email)) return true;

  const db = getFirestore();
  const platform = await db.doc(`platformAdmins/${uid}`).get();
  if (platform.exists) return true;

  const org = await db.doc(`organizations/${orgId}`).get();
  if (!org.exists) return false;
  if (org.data()?.createdByUid === uid) return true;

  const member = await db.doc(`organizations/${orgId}/members/${uid}`).get();
  return member.exists && member.data()?.role === "orgAdmin";
}

function registerOrgLogoFunctions(exports) {
  const { onRequest } = require("firebase-functions/v2/https");

  /**
   * GET  ?orgId=  — image bytes for any signed-in user (incl. guest).
   * POST JSON: { orgId, contentType, dataBase64 } — org / overall admin only.
   * Header: Authorization: Bearer <Firebase ID token>
   * Object: organizations/{orgId}/logo.jpg
   */
  exports.uploadOrgLogo = onRequest(
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
      let email;
      let isAnonymous = false;
      try {
        const decoded = await getAuth().verifyIdToken(idToken);
        uid = decoded.uid;
        email = decoded.email || "";
        isAnonymous = decoded.firebase?.sign_in_provider === "anonymous";
      } catch (err) {
        console.error("uploadOrgLogo auth error:", err);
        res.status(401).json({
          error: "Invalid or expired sign-in. Please sign in again.",
        });
        return;
      }

      if (req.method === "GET") {
        const orgId =
          typeof req.query?.orgId === "string"
            ? req.query.orgId.trim()
            : Array.isArray(req.query?.orgId)
              ? String(req.query.orgId[0] || "").trim()
              : "";
        if (!orgId || orgId.length > 128 || !/^[A-Za-z0-9_-]+$/.test(orgId)) {
          res.status(400).json({ error: "Organization is required." });
          return;
        }
        try {
          const bucket = getStorage().bucket();
          const objectPath = `organizations/${orgId}/logo.jpg`;
          const file = bucket.file(objectPath);
          const [exists] = await file.exists();
          if (!exists) {
            res.status(404).json({ error: "No organization logo" });
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
          console.error("uploadOrgLogo GET error:", err);
          res.status(500).json({ error: "Could not load the organization logo" });
        }
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      if (isAnonymous) {
        res.status(403).json({
          error: "Sign in with an administrator account to set the logo.",
        });
        return;
      }

      const orgId =
        typeof req.body?.orgId === "string" ? req.body.orgId.trim() : "";
      if (!orgId || orgId.length > 128) {
        res.status(400).json({ error: "Organization is required." });
        return;
      }

      try {
        const allowed = await canSetOrgLogo(uid, email, orgId);
        if (!allowed) {
          res.status(403).json({
            error:
              "Only organization administrators and overall administrators can set the logo.",
          });
          return;
        }
      } catch (err) {
        console.error("uploadOrgLogo permission error:", err);
        res.status(500).json({ error: "Could not verify administrator access." });
        return;
      }

      const contentType =
        typeof req.body?.contentType === "string" &&
        req.body.contentType.startsWith("image/")
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
        res.status(400).json({
          error: "Logo is too large. Maximum size is 5 MB.",
        });
        return;
      }

      try {
        const bucket = getStorage().bucket();
        const objectPath = `organizations/${orgId}/logo.jpg`;
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

        const downloadUrl = buildDownloadUrl(
          bucket.name,
          objectPath,
          downloadToken
        );

        await getFirestore().doc(`organizations/${orgId}`).update({
          logoUrl: downloadUrl,
          updatedAt: FieldValue.serverTimestamp(),
        });

        res.status(200).json({ downloadUrl });
      } catch (err) {
        console.error("uploadOrgLogo storage error:", err);
        res.status(500).json({ error: "Could not save the organization logo" });
      }
    }
  );
}

module.exports = { registerOrgLogoFunctions };
