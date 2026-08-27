const { getAuth } = require("firebase-admin/auth");
const { isFoundationAdminEmail } = require("./admin_config");

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

async function isSuperAdmin(db, decoded) {
  if (isFoundationAdminEmail(decoded.email)) return true;
  const snap = await db.collection("platformAdmins").doc(decoded.uid).get();
  return snap.exists;
}

module.exports = { verifyIdToken, isSuperAdmin };
