const { onRequest } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { createHash } = require("crypto");
const { verifyIdToken, isSuperAdmin } = require("./usage_report_auth");
const {
  THEMES,
  SOURCES,
  aggregateQuestionThemes,
} = require("./question_theme_aggregate");

const HASH_PEPPER = "wwjd-di-question-theme-v1";

function hashUser(uid) {
  return createHash("sha256")
    .update(`${HASH_PEPPER}:${uid}`)
    .digest("hex");
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  return null;
}

function memberGroupIds(snap) {
  if (!snap.exists) return [];
  const raw = snap.data()?.groupIds;
  return Array.isArray(raw) ? raw.map((id) => String(id)) : [];
}

async function isOrgAdminOnly(db, uid, orgId) {
  if (!orgId) return false;
  const orgSnap = await db.collection("organizations").doc(orgId).get();
  if (!orgSnap.exists) return false;
  if (orgSnap.data()?.createdByUid === uid) return true;
  const memberSnap = await db
    .collection("organizations")
    .doc(orgId)
    .collection("members")
    .doc(uid)
    .get();
  return memberSnap.exists && memberSnap.data()?.role === "orgAdmin";
}

async function validateScope(db, uid, organizationId, groupId) {
  const orgId = typeof organizationId === "string" ? organizationId.trim() : "";
  let gId = typeof groupId === "string" ? groupId.trim() : "";
  if (!orgId) return { organizationId: null, groupId: null };

  const memberSnap = await db
    .collection("organizations")
    .doc(orgId)
    .collection("members")
    .doc(uid)
    .get();
  if (!memberSnap.exists) {
    return { organizationId: null, groupId: null };
  }
  if (gId && !memberGroupIds(memberSnap).includes(gId)) {
    gId = "";
  }
  return {
    organizationId: orgId,
    groupId: gId || null,
  };
}

async function loadEvents(db, { organizationId, since }) {
  let query = db.collection("questionThemeEvents");
  if (organizationId) {
    query = query.where("organizationId", "==", organizationId);
  }
  if (since) {
    query = query.where("recordedAt", ">=", since);
  }
  const snap = await query.get();
  return snap.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      theme: data.theme,
      source: data.source,
      recordedAt: toDate(data.recordedAt),
      userHash: data.userHash,
      organizationId: data.organizationId || null,
      groupId: data.groupId || null,
    };
  });
}

function registerQuestionThemeFunctions(exports) {
  exports.recordQuestionTheme = onRequest(
    { cors: true, invoker: "public" },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      try {
        const decoded = await verifyIdToken(req);
        const theme = String(req.body?.theme || "").trim();
        const source = String(req.body?.source || "").trim();
        if (!THEMES.includes(theme) || !SOURCES.includes(source)) {
          res.status(400).json({ error: "Invalid theme or source" });
          return;
        }
        if (
          req.body?.question ||
          req.body?.text ||
          req.body?.displayName ||
          req.body?.email ||
          req.body?.uid
        ) {
          res.status(400).json({
            error: "Question text and identity are not accepted",
          });
          return;
        }

        const db = getFirestore();
        const scope = await validateScope(
          db,
          decoded.uid,
          req.body?.organizationId,
          req.body?.groupId
        );

        const userHash = hashUser(decoded.uid);
        const dayKey = new Date().toISOString().slice(0, 10);
        const recent = await db
          .collection("questionThemeEvents")
          .where("userHash", "==", userHash)
          .where("dayKey", "==", dayKey)
          .limit(40)
          .get();
        if (recent.size >= 40) {
          res.status(200).json({ ok: true, skipped: "rate_limited" });
          return;
        }

        await db.collection("questionThemeEvents").add({
          theme,
          source,
          recordedAt: FieldValue.serverTimestamp(),
          dayKey,
          userHash,
          ...(scope.organizationId
            ? { organizationId: scope.organizationId }
            : {}),
          ...(scope.groupId ? { groupId: scope.groupId } : {}),
        });

        res.status(200).json({ ok: true });
      } catch (err) {
        res.status(err.status || 500).json({ error: err.message || "Failed" });
      }
    }
  );

  exports.getQuestionThemeReport = onRequest(
    { cors: true, invoker: "public", timeoutSeconds: 120 },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      try {
        const decoded = await verifyIdToken(req);
        const db = getFirestore();
        const superAdmin = await isSuperAdmin(db, decoded);
        const orgId =
          typeof req.body?.organizationId === "string"
            ? req.body.organizationId.trim()
            : "";
        const groupId =
          typeof req.body?.groupId === "string" ? req.body.groupId.trim() : "";
        const sourceRaw = String(req.body?.source || "").trim();
        const source = SOURCES.includes(sourceRaw) ? sourceRaw : null;

        if (!superAdmin) {
          if (!orgId) {
            res.status(403).json({
              error: "Organization administrator access required",
            });
            return;
          }
          if (!(await isOrgAdminOnly(db, decoded.uid, orgId))) {
            res.status(403).json({
              error: "Organization administrator access required",
            });
            return;
          }
        }

        const rawDays = req.body?.periodDays;
        const periodDays =
          rawDays === null || rawDays === undefined || rawDays === "all"
            ? null
            : Math.min(Math.max(Number(rawDays) || 30, 1), 3660);

        const now = new Date();
        const lookbackDays = periodDays == null ? 3660 : periodDays * 2;
        const since = new Date(now.getTime() - lookbackDays * 86400000);

        const events = await loadEvents(db, {
          organizationId: superAdmin && !orgId ? null : orgId || null,
          since,
        });

        const aggregation = aggregateQuestionThemes({
          events,
          now,
          periodDays,
          organizationId: orgId || null,
          groupId: groupId || null,
          source,
        });

        res.status(200).json({
          generatedAt: now.toISOString(),
          periodDays,
          organizationId: orgId || null,
          groupId: aggregation.rolledUpFromGroup ? null : groupId || null,
          source,
          isSynthetic: false,
          note:
            "Aggregated distinct-person counts only. Question text, names, email, and uid are never stored on these events.",
          ...aggregation,
        });
      } catch (err) {
        res
          .status(err.status || 500)
          .json({ error: err.message || "Failed to load theme report" });
      }
    }
  );
}

module.exports = { registerQuestionThemeFunctions };
