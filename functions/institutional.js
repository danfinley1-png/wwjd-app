const { onRequest } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const {
  isFoundationAdminEmail,
  generateTemporaryPassword,
} = require("./admin_config");
const { resendApiKey } = require("./email_config");
const { sendProvisionWelcomeEmail } = require("./institutional_emails");
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

        res.status(200).json({ ok: true });
      } catch (err) {
        res.status(err.status || 500).json({ error: err.message || "Failed" });
      }
    }
  );

  exports.provisionInstitutionalUsers = onRequest(
    { cors: true, invoker: "public", timeoutSeconds: 120, secrets: [resendApiKey] },
    async (req, res) => {      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      try {
        const decoded = await verifyIdToken(req);
        const orgId = req.body?.orgId;
        const users = req.body?.users;
        if (!orgId || !Array.isArray(users) || users.length === 0) {
          res.status(400).json({ error: "orgId and users[] required" });
          return;
        }
        if (users.length > 100) {
          res.status(400).json({ error: "Maximum 100 users per upload" });
          return;
        }

        const db = getFirestore();
        if (!(await canProvisionUsers(db, decoded, orgId))) {
          res.status(403).json({ error: "Missing sufficient permissions" });
          return;
        }

        const orgSnap = await db.collection("organizations").doc(orgId).get();
        if (!orgSnap.exists) {
          res.status(404).json({ error: "Organization not found" });
          return;
        }

        const organizationName = (orgSnap.data()?.name || "").trim() || null;

        const created = [];
        const skipped = [];
        const auth = getAuth();

        for (const entry of users) {
          const email = (entry?.email || "").trim().toLowerCase();
          const displayName = (entry?.displayName || "").trim();
          if (!email || !email.includes("@")) {
            skipped.push(email || "(invalid)");
            continue;
          }

          try {
            let userRecord;
            try {
              userRecord = await auth.getUserByEmail(email);
              skipped.push(email);
              continue;
            } catch (lookupErr) {
              if (lookupErr.code !== "auth/user-not-found") throw lookupErr;
            }

            const tempPassword = generateTemporaryPassword();
            userRecord = await auth.createUser({
              email,
              password: tempPassword,
              displayName: displayName || undefined,
              emailVerified: false,
            });

            await db.collection("users").doc(userRecord.uid).set(
              {
                email,
                displayName: displayName || null,
                mustChangePassword: true,
                accountStatus: "pending_password",
                hasSeenInstitutionalWelcome: false,
                provisionedByOrgId: orgId,
                shareAnonymouslyByDefault: true,
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
              },
              { merge: true }
            );

            const welcomeEmail = await sendProvisionWelcomeEmail({
              email,
              displayName: displayName || null,
              temporaryPassword: tempPassword,
              organizationName,
              orgId,
            });

            created.push({
              email,
              displayName: displayName || null,
              temporaryPassword: tempPassword,
              welcomeEmailSent: welcomeEmail.ok,
              ...(welcomeEmail.error
                ? { welcomeEmailError: welcomeEmail.error }
                : {}),
            });          } catch (userErr) {
            console.error("provision user error", email, userErr);
            skipped.push(email);
          }
        }

        res.status(200).json({ created, skipped });
      } catch (err) {
        res.status(err.status || 500).json({ error: err.message || "Failed" });
      }
    }
  );
}

module.exports = { registerInstitutionalFunctions };
