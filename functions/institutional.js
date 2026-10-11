const { onRequest } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { isFoundationAdminEmail } = require("./admin_config");
const { resendApiKey } = require("./email_config");
const { handleBulkRoster } = require("./bulk_roster");

async function verifyIdToken(req) {
  const authHeader = req.headers.authorization || "";
  const idToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (!idToken) {
    const err = new Error("Sign in required");
    err.status = 401;
    throw err;
  }
  try {
    return await getAuth().verifyIdToken(idToken);
  } catch (e) {
    const err = new Error("Invalid or expired sign-in");
    err.status = 401;
    throw err;
  }
}

async function isOrgAdmin(db, uid, orgId) {
  const orgSnap = await db.collection("organizations").doc(orgId).get();
  if (!orgSnap.exists) return false;
  if (orgSnap.data().createdByUid === uid) return true;

  const memberSnap = await db
    .collection("organizations")
    .doc(orgId)
    .collection("members")
    .doc(uid)
    .get();
  if (!memberSnap.exists) return false;
  const role = memberSnap.data().role;
  return role === "orgAdmin" || role === "groupLeader";
}

async function isSuperAdmin(db, decoded) {
  if (isFoundationAdminEmail(decoded.email)) return true;
  const snap = await db.collection("platformAdmins").doc(decoded.uid).get();
  return snap.exists;
}

async function isOrgAdminRole(db, uid, orgId) {
  const orgSnap = await db.collection("organizations").doc(orgId).get();
  if (!orgSnap.exists) return false;
  if (orgSnap.data().createdByUid === uid) return true;

  const memberSnap = await db
    .collection("organizations")
    .doc(orgId)
    .collection("members")
    .doc(uid)
    .get();
  if (!memberSnap.exists) return false;
  return memberSnap.data().role === "orgAdmin";
}

async function canRegisterAccounts(db, decoded, orgId) {
  if (isFoundationAdminEmail(decoded.email)) return true;
  if (await isSuperAdmin(db, decoded)) return true;
  return isOrgAdminRole(db, decoded.uid, orgId);
}

async function canProvisionUsers(db, decoded, orgId) {
  if (isFoundationAdminEmail(decoded.email)) return true;
  if (await isSuperAdmin(db, decoded)) return true;
  return isOrgAdmin(db, decoded.uid, orgId);
}

function registerInstitutionalFunctions(exports) {
  exports.ensurePlatformAdmin = onRequest(
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
        const email = decoded.email?.toLowerCase();
        if (!isFoundationAdminEmail(email)) {
          res.status(403).json({ error: "Not a foundation administrator" });
          return;
        }

        const db = getFirestore();
        await db.collection("platformAdmins").doc(decoded.uid).set(
          {
            email,
            role: "superAdmin",
            registeredAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        await getAuth().setCustomUserClaims(decoded.uid, { admin: true });

        res.status(200).json({ ok: true, adminClaim: true });
      } catch (err) {
        res.status(err.status || 500).json({ error: err.message || "Failed" });
      }
    }
  );

  exports.provisionInstitutionalUsers = onRequest(
    {
      cors: true,
      invoker: "public",
      timeoutSeconds: 180,
      secrets: [resendApiKey],
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

      try {
        const decoded = await verifyIdToken(req);
        const orgIdRaw = req.body?.orgId;
        const orgId = typeof orgIdRaw === "string" ? orgIdRaw.trim() : "";
        const target = String(req.body?.target || "").trim().toLowerCase();
        const isPlatform =
          target === "platform" ||
          target === "wwjd-di" ||
          (!orgId && target !== "organization");
        const users = req.body?.users;
        const mode = req.body?.mode;
        if (!Array.isArray(users) || users.length === 0) {
          res.status(400).json({ error: "users[] required" });
          return;
        }
        if (!isPlatform && !orgId) {
          res.status(400).json({ error: "orgId and users[] required" });
          return;
        }
        if (users.length > 100) {
          res.status(400).json({ error: "Maximum 100 users per upload" });
          return;
        }

        const db = getFirestore();
        let canInvite;
        let canRegister;
        if (isPlatform) {
          const superAdmin = await isSuperAdmin(db, decoded);
          if (!superAdmin) {
            res.status(403).json({ error: "Overall Admin access required" });
            return;
          }
          canInvite = true;
          canRegister = true;
        } else {
          canInvite = await canProvisionUsers(db, decoded, orgId);
          canRegister = await canRegisterAccounts(db, decoded, orgId);
          if (!canInvite && !canRegister) {
            res.status(403).json({ error: "Missing sufficient permissions" });
            return;
          }
        }

        const groupIds = isPlatform
          ? []
          : Array.isArray(req.body?.groupIds)
            ? req.body.groupIds.map((id) => String(id)).filter(Boolean)
            : [];
        const emailSubject =
          typeof req.body?.emailSubject === "string"
            ? req.body.emailSubject
            : "";
        const emailText =
          typeof req.body?.emailText === "string" ? req.body.emailText : "";
        const attachOrgInvite = isPlatform
          ? false
          : req.body?.attachOrgInvite !== false;

        const result = await handleBulkRoster({
          decoded,
          orgId: isPlatform ? null : orgId,
          mode,
          users,
          groupIds,
          attachOrgInvite,
          emailSubject,
          emailText,
          canInvite,
          canRegister,
          isPlatform,
        });

        res.status(200).json(result);
      } catch (err) {
        res.status(err.status || 500).json({ error: err.message || "Failed" });
      }
    }
  );
}

module.exports = { registerInstitutionalFunctions };
