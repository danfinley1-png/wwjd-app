const { appUrl, EMAIL_LOGO_URL, EMAIL_LOGO_CONTENT_ID } = require("./email_config");

const APP_PUBLIC_URL = "https://wwjd-di-e36ce.web.app";
const TEMP_PASSWORD_PLACEHOLDER =
  "[temporary password — assigned when Send is tapped]";

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

function openAppInstructionsText() {
  return [
    "Open WWJD-DI",
    `1. Tap this link: ${APP_PUBLIC_URL}`,
    "2. Sign in with the email this message was sent to (set your password on first login if prompted).",
    "3. Add to your phone Home Screen:",
    "   iPhone: Safari → Share → Add to Home Screen. Use the WWJD-DI icon.",
    "   Android: Chrome → menu → Add to Home screen / Install app.",
  ].join("\n");
}

function openAppInstructionsHtml() {
  return `<p style="margin:20px 0 8px;"><strong>Open WWJD-DI</strong></p>
<ol style="margin:0;padding-left:20px;">
  <li>Tap this link: <a href="${escapeHtml(APP_PUBLIC_URL)}">${escapeHtml(APP_PUBLIC_URL)}</a></li>
  <li>Sign in with the email this message was sent to (set your password on first login if prompted).</li>
  <li>Add to your phone Home Screen:<br>
    iPhone: Safari → Share → Add to Home Screen. Use the WWJD-DI icon.<br>
    Android: Chrome → menu → Add to Home screen / Install app.
  </li>
</ol>`;
}

function logoHtml() {
  const httpsSrc = escapeHtml(EMAIL_LOGO_URL);
  const cidSrc = `cid:${EMAIL_LOGO_CONTENT_ID}`;
  return `<p style="margin:0 0 8px;">
  <img src="${httpsSrc}" alt="WWJD-DI" width="96" height="96" style="display:block;border:0;width:96px;height:96px;" />
  <img src="${cidSrc}" alt="WWJD-DI" width="96" height="96" style="display:none;max-height:0;overflow:hidden;" />
</p>
<p style="margin:0 0 16px;font-family:Georgia,'Times New Roman',serif;font-size:20px;font-weight:bold;color:#6b1c23;">WWJD-DI</p>`;
}

function brandedEmailHtml(innerHtml) {
  return `<!DOCTYPE html>
<html lang="en">
<body style="font-family: Georgia, 'Times New Roman', serif; color: #1f1f1f; line-height: 1.6; max-width: 560px;">
  ${logoHtml()}
  ${innerHtml}
</body>
</html>`;
}

function htmlFromPlainText(text) {
  const trimmed = String(text ?? "").trim();
  if (!trimmed) return "";
  return trimmed
    .split(/\n{2,}/)
    .map((block) => `<p>${escapeHtml(block).replace(/\n/g, "<br>")}</p>`)
    .join("\n");
}

function applyPlainEmailOverride(built, { emailSubject, emailText } = {}) {
  const subject = String(emailSubject || "").trim();
  const text = String(emailText || "").trim();
  if (!subject && !text) return built;
  const nextSubject = subject || built.subject;
  const nextText = text || built.text;
  return {
    ...built,
    subject: nextSubject,
    text: nextText,
    html: brandedEmailHtml(htmlFromPlainText(nextText)),
  };
}

function applyWelcomeOverride(built, { emailSubject, emailText, temporaryPassword } = {}) {
  const password = String(temporaryPassword || "");
  let subject = String(emailSubject || "").trim() || built.subject;
  let text = String(emailText || "").trim() || built.text;
  text = text
    .split("{{temporaryPassword}}")
    .join(password)
    .split(TEMP_PASSWORD_PLACEHOLDER)
    .join(password);
  if (password && !text.includes(password)) {
    text = `${text}\n\nYour temporary password: ${password}`;
  }
  return {
    ...built,
    subject,
    text,
    html: brandedEmailHtml(htmlFromPlainText(text)),
  };
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
    : "<p>Your WWJD-DI account is ready. Personal discernment features are available after you sign in.</p>";

  const signInUrl = APP_PUBLIC_URL;
  const subject = "Welcome to WWJD-DI — your account is ready";

  const text = [
    `Dear ${greeting},`,
    "",
    "Welcome to WWJD-DI — a Catholic discernment companion rooted in Scripture and Church teaching.",
    "",
    organizationName
      ? `Your account was set up for ministry use with ${organizationName}.`
      : "Your WWJD-DI account is ready. Personal discernment features are available after you sign in.",
    "",
    "Your next steps:",
    `1. Open WWJD-DI: ${signInUrl}`,
    `2. Sign in with this email address: ${email}`,
    `3. Use this temporary password: ${temporaryPassword}`,
    "4. You will be asked to choose a new password on first sign-in.",
    "",
    openAppInstructionsText(),
    "",
    "Privacy: Your personal conversations in Seeking God's Wisdom, reflections, and gifts are private. Organization leaders cannot read them.",
    "",
    "Peace in Christ,",
    "The WWJD-DI Team",
  ].join("\n");

  const inner = `
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
  ${openAppInstructionsHtml()}
  <p style="font-size: 14px; color: #555;">
    <strong>Privacy:</strong> Your personal conversations in Seeking God's Wisdom, reflections, and gifts stay private.
    Organization leaders cannot read them.
  </p>
  <p>Peace in Christ,<br>The WWJD-DI Team</p>`;

  return { subject, text, html: brandedEmailHtml(inner) };
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
  const homeUrl = APP_PUBLIC_URL;
  const groupLabel = (groupName || "your ministry group").trim();
  const orgLabel = (organizationName || "").trim();

  const subject = orgLabel
    ? `You're invited to join ${groupLabel} on WWJD-DI — ${orgLabel}`
    : `You're invited to join ${groupLabel} on WWJD-DI`;

  const orgSentence = orgLabel ? ` at ${orgLabel}` : "";

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
    "",
    openAppInstructionsText(),
    "",
    "This message contains no private spiritual content.",
    "",
    "Peace in Christ,",
    "The WWJD-DI Team",
  ].join("\n");

  const orgHtml = orgLabel
    ? ` at <strong>${escapeHtml(orgLabel)}</strong>`
    : "";

  const inner = `
  <p>Hello,</p>
  <p>You have been invited to join the group <strong>${escapeHtml(groupLabel)}</strong>${orgHtml} in WWJD-DI.</p>
  <p>WWJD-DI is a Catholic discernment companion rooted in Scripture and Church teaching.</p>
  <p>You may <strong>Accept</strong> or <strong>Decline</strong> this invitation in the app — membership is never added without your consent.</p>
  <p>
    <a href="${escapeHtml(invitesUrl)}" style="display:inline-block;padding:10px 18px;background:#6b1c23;color:#fff;text-decoration:none;border-radius:6px;">View invitations</a>
  </p>
  ${openAppInstructionsHtml()}
  <p style="font-size: 14px; color: #555;">
    Or <a href="${escapeHtml(homeUrl)}">open WWJD-DI</a> and check the home screen or My Profile → Messages.
  </p>
  <p>Peace in Christ,<br>The WWJD-DI Team</p>`;

  return { subject, text, html: brandedEmailHtml(inner), to: inviteeEmail };
}

function roleLabel(role) {
  switch (role) {
    case "orgAdmin":
      return "organization administrator";
    case "groupLeader":
      return "group leader";
    default:
      return "member";
  }
}

/**
 * Notification when a person is invited to join an organization.
 */
function buildOrganizationInviteEmail({
  inviteeEmail,
  organizationName,
  role,
  groupNames = [],
}) {
  const homeUrl = APP_PUBLIC_URL;
  const orgLabel = (organizationName || "your organization").trim();
  const roleText = roleLabel(role);
  const groups = (groupNames || []).map((n) => String(n).trim()).filter(Boolean);

  const subject = `You're invited to join ${orgLabel} on WWJD-DI`;

  const groupsText = groups.length
    ? ` Assigned groups after you accept: ${groups.join(", ")}.`
    : "";

  const text = [
    "Hello,",
    "",
    `You have been invited to join ${orgLabel} in WWJD-DI as a ${roleText}.${groupsText}`,
    "",
    "WWJD-DI is a Catholic discernment companion rooted in Scripture and Church teaching.",
    "",
    "You may Accept or Decline this invitation in the app — membership is never added without your consent.",
    "",
    openAppInstructionsText(),
    "",
    "This message contains no private spiritual content.",
    "",
    "Peace in Christ,",
    "The WWJD-DI Team",
  ].join("\n");

  const groupsHtml = groups.length
    ? `<p>Assigned groups after you accept: <strong>${groups
        .map(escapeHtml)
        .join("</strong>, <strong>")}</strong>.</p>`
    : "";

  const inner = `
  <p>Hello,</p>
  <p>You have been invited to join <strong>${escapeHtml(orgLabel)}</strong> in WWJD-DI as a ${escapeHtml(roleText)}.</p>
  ${groupsHtml}
  <p>WWJD-DI is a Catholic discernment companion rooted in Scripture and Church teaching.</p>
  <p>You may <strong>Accept</strong> or <strong>Decline</strong> this invitation in the app — membership is never added without your consent.</p>
  <p>
    <a href="${escapeHtml(homeUrl)}" style="display:inline-block;padding:10px 18px;background:#6b1c23;color:#fff;text-decoration:none;border-radius:6px;">Open WWJD-DI</a>
  </p>
  ${openAppInstructionsHtml()}
  <p>Peace in Christ,<br>The WWJD-DI Team</p>`;

  return { subject, text, html: brandedEmailHtml(inner), to: inviteeEmail };
}

/**
 * Invitation to WWJD-DI with no organization or group.
 */
function buildPlatformInviteEmail({ inviteeEmail }) {
  const homeUrl = APP_PUBLIC_URL;
  const subject = "You're invited to WWJD-DI";

  const text = [
    "Hello,",
    "",
    "You have been invited to use WWJD-DI, a Catholic discernment companion rooted in Scripture and Church teaching.",
    "",
    "Register or sign in with the email this message was sent to. Personal features such as Seeking God's Wisdom are available after you create your account.",
    "",
    "A school, parish, or ministry is added only if you later accept a separate invitation. Nothing is assigned automatically.",
    "",
    openAppInstructionsText(),
    "",
    "This message contains no private spiritual content.",
    "",
    "Peace in Christ,",
    "The WWJD-DI Team",
  ].join("\n");

  const inner = `
  <p>Hello,</p>
  <p>You have been invited to use <strong>WWJD-DI</strong>, a Catholic discernment companion rooted in Scripture and Church teaching.</p>
  <p>Register or sign in with the email this message was sent to. Personal features such as Seeking God's Wisdom are available after you create your account.</p>
  <p>A school, parish, or ministry is added only if you later accept a separate invitation. Nothing is assigned automatically.</p>
  <p>
    <a href="${escapeHtml(homeUrl)}" style="display:inline-block;padding:10px 18px;background:#6b1c23;color:#fff;text-decoration:none;border-radius:6px;">Open WWJD-DI</a>
  </p>
  ${openAppInstructionsHtml()}
  <p>Peace in Christ,<br>The WWJD-DI Team</p>`;

  return { subject, text, html: brandedEmailHtml(inner), to: inviteeEmail };
}

module.exports = {
  APP_PUBLIC_URL,
  TEMP_PASSWORD_PLACEHOLDER,
  openAppInstructionsText,
  brandedEmailHtml,
  htmlFromPlainText,
  applyPlainEmailOverride,
  applyWelcomeOverride,
  buildWelcomeEmail,
  buildGroupInviteEmail,
  buildOrganizationInviteEmail,
  buildPlatformInviteEmail,
};
