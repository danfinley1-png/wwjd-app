const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { resendApiKey, emailFrom } = require("./email_config");

/**
 * Sends email via Resend REST API. Returns { ok, id?, error? }.
 * Never throws — callers decide whether to fail the parent operation.
 */
async function sendEmail({ to, subject, html, text, tags = [] }) {
  const apiKey = resendApiKey.value();
  const from = emailFrom.value();

  if (!apiKey) {
    console.warn("sendEmail skipped: RESEND_API_KEY is not configured");
    return { ok: false, error: "RESEND_API_KEY is not configured" };
  }

  if (!to || !subject) {
    return { ok: false, error: "Missing recipient or subject" };
  }

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject,
        html,
        text,
        tags,
      }),
    });

    const body = await response.json().catch(() => ({}));

    if (!response.ok) {
      const message =
        body?.message || body?.error || `Resend HTTP ${response.status}`;
      console.error("sendEmail failed:", to, message, body);
      return { ok: false, error: message };
    }

    console.log("sendEmail success:", to, body?.id || "(no id)");
    return { ok: true, id: body?.id };
  } catch (err) {
    console.error("sendEmail error:", to, err);
    return { ok: false, error: err.message || "Email send failed" };
  }
}

/**
 * Optional delivery log for admin troubleshooting (no spiritual content).
 */
async function logEmailDelivery({
  type,
  to,
  ok,
  error,
  organizationId,
  inviteId,
  orgId,
}) {
  try {
    const db = getFirestore();
    const payload = {
      type,
      to,
      ok,
      error: error || null,
      organizationId: organizationId || orgId || null,
      inviteId: inviteId || null,
      createdAt: FieldValue.serverTimestamp(),
    };

    if (organizationId || orgId) {
      await db
        .collection("organizations")
        .doc(organizationId || orgId)
        .collection("emailDeliveryLogs")
        .add(payload);
    } else {
      await db.collection("platformEmailLogs").add(payload);
    }
  } catch (logErr) {
    console.warn("logEmailDelivery failed:", logErr.message);
  }
}

module.exports = {
  sendEmail,
  logEmailDelivery,
};
