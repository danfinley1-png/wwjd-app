/** Overall / Super administrator emails — keep in sync with lib/admin/config/admin_config.dart */
const FOUNDATION_ADMIN_EMAILS = [
  "dan.finley@verizon.net",
];

function isFoundationAdminEmail(email) {
  if (!email || typeof email !== "string") return false;
  return FOUNDATION_ADMIN_EMAILS.includes(email.trim().toLowerCase());
}

function generateTemporaryPassword() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#";
  let result = "Wwjd";
  for (let i = 0; i < 10; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result + "7";
}

module.exports = {
  FOUNDATION_ADMIN_EMAILS,
  isFoundationAdminEmail,
  generateTemporaryPassword,
};
