/**
 * One-time: set admin custom claim for a Firebase Auth user (Firestore rules + Storage).
 *
 * Usage (from functions/):
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\service-account.json
 *   node scripts/set_admin_claim.js USER_UID
 */
const admin = require("firebase-admin");

const uid = process.argv[2];
if (!uid) {
  console.error("Usage: node scripts/set_admin_claim.js USER_UID");
  process.exit(1);
}

admin.initializeApp();

admin
  .auth()
  .setCustomUserClaims(uid, { admin: true })
  .then(() => admin.auth().getUser(uid))
  .then((user) => {
    console.log("admin claim set for", user.email ?? uid);
    console.log("customClaims", user.customClaims);
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
