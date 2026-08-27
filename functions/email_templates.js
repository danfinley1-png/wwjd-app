const { appUrl } = require("./email_config");

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function firstName(displayName, email) {
  const fromName = (displayName || "").trim();
  if (fromName) return fromName.split(/\s+/)[0];
  const local = (email || "").split("@")[0] || "friend";
  return local.charAt(0).toUpperCase() + local.slice(1);
}

/**
 * Welcome email for admin-provisioned accounts (includes temporary password).
 */
function buildWelcomeEmail({
  email,
  displayName,
  temporaryPassword,
  organizationName,
}) {
  const greeting = firstName(displayName, email);
  const orgLine = organizationName
    ? `<p>Your account was set up for ministry use with <strong>${escapeHtml(organizationName)}</strong>.</p>`
    : "<p>Your account was set up for ministry or school use through your organization.</p>";

  const signInUrl = appUrl("/");
  const subject = "Welcome to WWJD-DI — your account is ready";

  const text = [
    `Dear ${greeting},`,
    "",
    "Welcome to WWJD-DI — a Catholic discernment companion rooted in Scripture and Church teaching.",
    "",
    organizationName
      ? `Your account was set up for ministry use with ${organizationName}.`
      : "Your account was set up for ministry or school use through your organization.",
    "",
    "Your next steps:",
    `1. Open the app: ${signInUrl}`,
    `2. Sign in with this email address: ${email}`,
    `3. Use this temporary password: ${temporaryPassword}`,
    "4. You will be asked to choose a new password on first sign-in.",
    "",
    "Privacy: Your personal conversations in Seeking God's Wisdom, reflections, and gifts are private. Organization leaders cannot read them.",
    "",
    "Peace in Christ,",
    "The WWJD-DI Team",
  ].join("\n");

  const html = `<!DOCTYPE html>
<html lang="en">
<body style="font-family: Georgia, 'Times New Roman', serif; color: #1f1f1f; line-height: 1.6; max-width: 560px;">
  <p>Dear ${escapeHtml(greeting)},</p>
  <p>Welcome to <strong>WWJD-DI</strong> — a Catholic discernment companion rooted in Scripture and Church teaching.</p>
  ${orgLine}
  <p><strong>Your next steps</strong></p>
  <ol>
    <li><a href="${escapeHtml(signInUrl)}">Open WWJD-DI</a></li>
    <li>Sign in with <strong>${escapeHtml(email)}</strong></li>
    <li>Use this temporary password: <strong>${escapeHtml(temporaryPassword)}</strong></li>
    <li>Choose a new password when prompted — this keeps your account secure.</li>
  </ol>
  <p style="font-size: 14px; color: #555;">
    <strong>Privacy:</strong> Your personal conversations in Seeking God's Wisdom, reflections, and gifts stay private.
    Organization leaders cannot read them.
  </p>
  <p>Peace in Christ,<br>The WWJD-DI Team</p>
</body>
</html>`;

  return { subject, text, html };
}

/**
 * Notification when a user is invited to a ministry group.
 */
function buildGroupInviteEmail({
  inviteeEmail,
  groupName,
  organizationName,
}) {
  const invitesUrl = appUrl("/group-invites");
  const homeUrl = appUrl("/");
  const groupLabel = (groupName || "your ministry group").trim();
  const orgLabel = (organizationName || "").trim();

  const subject = orgLabel
    ? `You're invited to join ${groupLabel} — ${orgLabel}`
    : `You're invited to join ${groupLabel}`;

  const orgSentence = orgLabel
    ? ` at ${orgLabel}`
    : "";

  const text = [
    "Hello,",
    "",
    `You have been invited to join the group "${groupLabel}"${orgSentence} in WWJD-DI.`,
    "",
    "WWJD-DI is a Catholic discernment companion rooted in Scripture and Church teaching.",
    "",
    "You may Accept or Decline this invitation in the app — membership is never added without your consent.",
    "",
    `View invitations: ${invitesUrl}`,
    `Or open the app: ${homeUrl}`,
    "",
    "This message contains no private spiritual content.",
    "",
    "Peace in Christ,",
    "The WWJD-DI Team",
  ].join("\n");

  const orgHtml = orgLabel
    ? ` at <strong>${escapeHtml(orgLabel)}</strong>`
    : "";

  const html = `<!DOCTYPE html>
<html lang="en">
<body style="font-family: Georgia, 'Times New Roman', serif; color: #1f1f1f; line-height: 1.6; max-width: 560px;">
  <p>Hello,</p>
  <p>You have been invited to join the group <strong>${escapeHtml(groupLabel)}</strong>${orgHtml} in WWJD-DI.</p>
  <p>WWJD-DI is a Catholic discernment companion rooted in Scripture and Church teaching.</p>
  <p>You may <strong>Accept</strong> or <strong>Decline</strong> this invitation in the app — membership is never added without your consent.</p>
  <p>
    <a href="${escapeHtml(invitesUrl)}" style="display:inline-block;padding:10px 18px;background:#6b1c23;color:#fff;text-decoration:none;border-radius:6px;">View invitations</a>
  </p>
  <p style="font-size: 14px; color: #555;">
    Or <a href="${escapeHtml(homeUrl)}">open WWJD-DI</a> and check the home screen or My Profile → Messages.
  </p>
  <p>Peace in Christ,<br>The WWJD-DI Team</p>
</body>
</html>`;

  return { subject, text, html, to: inviteeEmail };
}

module.exports = {
  buildWelcomeEmail,
  buildGroupInviteEmail,
};
