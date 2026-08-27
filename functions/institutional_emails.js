const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { resendApiKey } = require("./email_config");
const { buildWelcomeEmail, buildGroupInviteEmail } = require("./email_templates");
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
}) {
  const { subject, text, html } = buildWelcomeEmail({
    email,
    displayName,
    temporaryPassword,
    organizationName,
  });

  const result = await sendEmail({
    to: email,
    subject,
    html,
    text,
    tags: [{ name: "type", value: "welcome" }],
  });

  await logEmailDelivery({
    type: "welcome",
    to: email,
    ok: result.ok,
    error: result.error,
    organizationId: orgId,
  });

  return result;
}

function registerInstitutionalEmailFunctions(exports) {
  /**
   * Fires when a pending group invitation is created under an organization.
   * Path: organizations/{orgId}/groupInvites/{inviteId}
   */
  exports.onGroupInviteCreated = onDocumentCreated(
    {
      document: "organizations/{orgId}/groupInvites/{inviteId}",
      secrets: [resendApiKey],
    },
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const data = snap.data();
      if ((data.status || "pending") !== "pending") return;

      const inviteeEmail = (data.inviteeEmail || "").trim().toLowerCase();
      if (!inviteeEmail || !inviteeEmail.includes("@")) {
        console.warn(
          "onGroupInviteCreated: missing inviteeEmail",
          event.params.inviteId
        );
        return;
      }

      let organizationName = (data.organizationName || "").trim();
      if (!organizationName) {
        try {
          const orgSnap = await getFirestore()
            .collection("organizations")
            .doc(event.params.orgId)
            .get();
          organizationName = (orgSnap.data()?.name || "").trim();
        } catch (err) {
          console.warn("onGroupInviteCreated: org lookup failed", err.message);
        }
      }

      const { subject, text, html, to } = buildGroupInviteEmail({
        inviteeEmail,
        groupName: data.groupName,
        organizationName,
      });

      const result = await sendEmail({
        to,
        subject,
        html,
        text,
        tags: [{ name: "type", value: "group_invite" }],
      });

      await logEmailDelivery({
        type: "group_invite",
        to,
        ok: result.ok,
        error: result.error,
        organizationId: event.params.orgId,
        inviteId: event.params.inviteId,
      });
    }
  );
}

module.exports = {
  registerInstitutionalEmailFunctions,
  sendProvisionWelcomeEmail,
};
