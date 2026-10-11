const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { resendApiKey, EMAIL_FROM } = require("./email_config");
const {
  buildWelcomeEmail,
  buildGroupInviteEmail,
  buildOrganizationInviteEmail,
  buildPlatformInviteEmail,
  applyPlainEmailOverride,
  applyWelcomeOverride,
} = require("./email_templates");
const { sendEmail, logEmailDelivery } = require("./email_service");

/**
 * Sends welcome email after admin provisioning. Non-blocking for the caller.
 */
async function sendProvisionWelcomeEmail({
  email,
  displayName,
  temporaryPassword,
  organizationName,
  orgId,
  emailSubject,
  emailText,
}) {
  let { subject, text, html } = buildWelcomeEmail({
    email,
    displayName,
    temporaryPassword,
    organizationName,
  });

  if (String(emailSubject || "").trim() || String(emailText || "").trim()) {
    ({ subject, text, html } = applyWelcomeOverride(
      { subject, text, html },
      { emailSubject, emailText, temporaryPassword }
    ));
  }

  const result = await sendEmail({
    to: email,
    subject,
    html,
    text,
    tags: [{ name: "type", value: "welcome" }],
  });

  const from = result.from || EMAIL_FROM;
  console.log("invite email", {
    type: "welcome",
    inviteId: null,
    to: email,
    from,
    resendStatus: result.ok ? "sent" : "failed",
    resendId: result.id || null,
    error: result.error || null,
  });

  await logEmailDelivery({
    type: "welcome",
    to: email,
    from,
    ok: result.ok,
    error: result.error,
    organizationId: orgId,
    resendId: result.id,
  });

  return result;
}

async function sendOrganizationInviteEmail({
  email,
  organizationName,
  role,
  groupNames = [],
  orgId,
  inviteId,
  emailSubject,
  emailText,
}) {
  let built = buildOrganizationInviteEmail({
    inviteeEmail: email,
    organizationName,
    role: role || "member",
    groupNames,
  });
  built = applyPlainEmailOverride(built, { emailSubject, emailText });

  const result = await sendEmail({
    to: built.to,
    subject: built.subject,
    html: built.html,
    text: built.text,
    tags: [{ name: "type", value: "org_invite" }],
  });

  const from = result.from || EMAIL_FROM;
  console.log("invite email", {
    type: "org_invite",
    inviteId: inviteId || null,
    to: built.to,
    from,
    resendStatus: result.ok ? "sent" : "failed",
    resendId: result.id || null,
    error: result.error || null,
  });

  await logEmailDelivery({
    type: "org_invite",
    to: built.to,
    from,
    ok: result.ok,
    error: result.error,
    organizationId: orgId,
    inviteId,
    resendId: result.id,
  });

  return result;
}

async function sendPlatformInviteEmail({
  email,
  inviteId,
  emailSubject,
  emailText,
}) {
  let built = buildPlatformInviteEmail({ inviteeEmail: email });
  built = applyPlainEmailOverride(built, { emailSubject, emailText });

  const result = await sendEmail({
    to: built.to,
    subject: built.subject,
    html: built.html,
    text: built.text,
    tags: [{ name: "type", value: "platform_invite" }],
  });

  const from = result.from || EMAIL_FROM;
  console.log("invite email", {
    type: "platform_invite",
    inviteId: inviteId || null,
    to: built.to,
    from,
    resendStatus: result.ok ? "sent" : "failed",
    resendId: result.id || null,
    error: result.error || null,
  });

  await logEmailDelivery({
    type: "platform_invite",
    to: built.to,
    from,
    ok: result.ok,
    error: result.error,
    inviteId,
    resendId: result.id,
  });

  return result;
}

async function sendGroupInviteEmail({
  email,
  groupName,
  organizationName,
  orgId,
  inviteId,
  emailSubject,
  emailText,
}) {
  let built = buildGroupInviteEmail({
    inviteeEmail: email,
    groupName,
    organizationName,
  });
  built = applyPlainEmailOverride(built, { emailSubject, emailText });

  const result = await sendEmail({
    to: built.to,
    subject: built.subject,
    html: built.html,
    text: built.text,
    tags: [{ name: "type", value: "group_invite" }],
  });

  const from = result.from || EMAIL_FROM;
  console.log("invite email", {
    type: "group_invite",
    inviteId: inviteId || null,
    to: built.to,
    from,
    resendStatus: result.ok ? "sent" : "failed",
    resendId: result.id || null,
    error: result.error || null,
  });

  await logEmailDelivery({
    type: "group_invite",
    to: built.to,
    from,
    ok: result.ok,
    error: result.error,
    organizationId: orgId,
    inviteId,
    resendId: result.id,
  });

  return result;
}

function isPending(data) {
  return (data?.status || "pending") === "pending";
}

/**
 * Send when the row is pending and mail has not been marked sent.
 * Re-send only if status newly became pending (revoke → invite again).
 */
function notifyRequestedMillis(data) {
  const value = data?.emailNotifyRequestedAt;
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function shouldSendInviteEmail(beforeData, afterData) {
  if (!afterData || !isPending(afterData)) return false;
  if (afterData.emailHold === true) return false;
  if (!afterData.inviteEmailSentAt) return true;
  if (!beforeData) return false;
  if (!isPending(beforeData)) return true;
  const afterReq = notifyRequestedMillis(afterData);
  const beforeReq = notifyRequestedMillis(beforeData);
  return afterReq > 0 && afterReq > beforeReq;
}

function inviteeAddress(data) {
  return String(data?.inviteeEmail || data?.email || "")
    .trim()
    .toLowerCase();
}

async function resolveOrganizationName(orgId, data) {
  const fromDoc = (data?.organizationName || "").trim();
  if (fromDoc) return fromDoc;
  if (!orgId) return "";
  try {
    const orgSnap = await getFirestore()
      .collection("organizations")
      .doc(orgId)
      .get();
    return (orgSnap.data()?.name || "").trim();
  } catch (err) {
    console.warn("invite email: org lookup failed", err.message);
    return "";
  }
}

async function resolveGroupNames(orgId, groupIds) {
  if (!Array.isArray(groupIds) || groupIds.length === 0) return [];
  const db = getFirestore();
  const names = [];
  for (const rawId of groupIds.slice(0, 20)) {
    const id = String(rawId || "").trim();
    if (!id) continue;
    try {
      const snap = await db
        .collection("organizations")
        .doc(orgId)
        .collection("groups")
        .doc(id)
        .get();
      const name = (snap.data()?.name || "").trim();
      if (name) names.push(name);
    } catch (err) {
      console.warn("invite email: group lookup failed", id, err.message);
    }
  }
  return names;
}

async function markInviteEmailSent(ref) {
  try {
    await ref.update({ inviteEmailSentAt: FieldValue.serverTimestamp() });
  } catch (err) {
    console.warn("invite email: could not mark inviteEmailSentAt", err.message);
  }
}

async function dispatchInviteEmail({
  kind,
  orgId,
  inviteId,
  data,
  docRef,
}) {
  const to = inviteeAddress(data);
  if (!to || !to.includes("@")) {
    console.warn("invite email: missing recipient", { kind, inviteId, orgId });
    return;
  }

  const organizationName = await resolveOrganizationName(orgId, data);
  let built;
  let type;

  if (kind === "platform") {
    type = "platform_invite";
    built = buildPlatformInviteEmail({ inviteeEmail: to });
  } else if (kind === "group") {
    type = "group_invite";
    built = buildGroupInviteEmail({
      inviteeEmail: to,
      groupName: data.groupName,
      organizationName,
    });
  } else {
    type = "org_invite";
    const groupNames = await resolveGroupNames(orgId, data.groupIds);
    built = buildOrganizationInviteEmail({
      inviteeEmail: to,
      organizationName,
      role: data.role,
      groupNames,
    });
  }

  built = applyPlainEmailOverride(built, {
    emailSubject: data.emailSubject,
    emailText: data.emailText,
  });

  const result = await sendEmail({
    to: built.to,
    subject: built.subject,
    html: built.html,
    text: built.text,
    tags: [{ name: "type", value: type }],
  });

  const from = result.from || EMAIL_FROM;
  const resendStatus = result.ok ? "sent" : "failed";

  console.log("invite email", {
    type,
    inviteId,
    to: built.to,
    from,
    resendStatus,
    resendId: result.id || null,
    error: result.error || null,
  });

  await logEmailDelivery({
    type,
    to: built.to,
    from,
    ok: result.ok,
    error: result.error,
    organizationId: orgId,
    inviteId,
    resendId: result.id,
  });

  if (result.ok) {
    await markInviteEmailSent(docRef);
  }
}

async function handleInviteCreated(event, kind) {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data() || {};
  if (!shouldSendInviteEmail(null, data)) return;
  await dispatchInviteEmail({
    kind,
    orgId: event.params.orgId || null,
    inviteId: event.params.inviteId,
    data,
    docRef: snap.ref,
  });
}

async function handleInviteUpdated(event, kind) {
  const change = event.data;
  if (!change?.after?.exists) return;
  const after = change.after.data() || {};
  const before = change.before?.exists ? change.before.data() : null;
  if (!shouldSendInviteEmail(before, after)) return;
  await dispatchInviteEmail({
    kind,
    orgId: event.params.orgId || null,
    inviteId: event.params.inviteId,
    data: after,
    docRef: change.after.ref,
  });
}

function registerInstitutionalEmailFunctions(exports) {
  const secrets = [resendApiKey];

  /**
   * Group consent invites written by Admin Members → Invite to group.
   * Path: organizations/{orgId}/groupInvites/{inviteId}
   */
  exports.onGroupInviteCreated = onDocumentCreated(
    {
      document: "organizations/{orgId}/groupInvites/{inviteId}",
      secrets,
    },
    (event) => handleInviteCreated(event, "group")
  );

  exports.onGroupInviteUpdated = onDocumentUpdated(
    {
      document: "organizations/{orgId}/groupInvites/{inviteId}",
      secrets,
    },
    (event) => handleInviteUpdated(event, "group")
  );

  /**
   * Organization email invites (Invite member). Admin writes this collection,
   * not groupInvites — that mismatch caused 0 invocations on the group trigger.
   * Path: organizations/{orgId}/invites/{inviteId}
   * Stable ids mean re-invites are updates, not creates.
   */
  exports.onOrganizationInviteCreated = onDocumentCreated(
    {
      document: "organizations/{orgId}/invites/{inviteId}",
      secrets,
    },
    (event) => handleInviteCreated(event, "org")
  );

  exports.onOrganizationInviteUpdated = onDocumentUpdated(
    {
      document: "organizations/{orgId}/invites/{inviteId}",
      secrets,
    },
    (event) => handleInviteUpdated(event, "org")
  );

  /**
   * WWJD-DI-only invites (no organization or group).
   * Path: platformInvites/{inviteId}
   */
  exports.onPlatformInviteCreated = onDocumentCreated(
    {
      document: "platformInvites/{inviteId}",
      secrets,
    },
    (event) => handleInviteCreated(event, "platform")
  );

  exports.onPlatformInviteUpdated = onDocumentUpdated(
    {
      document: "platformInvites/{inviteId}",
      secrets,
    },
    (event) => handleInviteUpdated(event, "platform")
  );
}

module.exports = {
  registerInstitutionalEmailFunctions,
  sendProvisionWelcomeEmail,
  sendOrganizationInviteEmail,
  sendPlatformInviteEmail,
  sendGroupInviteEmail,
  shouldSendInviteEmail,
};
