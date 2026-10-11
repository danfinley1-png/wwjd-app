const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const {
  resendApiKey,
  EMAIL_FROM,
  EMAIL_LOGO_URL,
  EMAIL_LOGO_CONTENT_ID,
} = require("./email_config");

/**
 * Sends email via Resend REST API. Returns { ok, id?, error? }.
 * Never throws — callers decide whether to fail the parent operation.
 */
async function sendEmail({ to, subject, html, text, tags = [] }) {
  const apiKey = resendApiKey.value();
  const from = EMAIL_FROM;

  if (/resend\.dev/i.test(from)) {
    console.error("sendEmail blocked: refusing Resend test-domain From", from);
    return {
      ok: false,
      from,
      error: "Refusing onboarding@resend.dev From address",
    };
  }

  if (!apiKey) {
    console.warn("sendEmail skipped: RESEND_API_KEY is not configured");
    return { ok: false, from, error: "RESEND_API_KEY is not configured" };
  }

  if (!to || !subject) {
    return { ok: false, from, error: "Missing recipient or subject" };
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
        attachments: [
          {
            filename: "wwjd-di-logo.png",
            path: EMAIL_LOGO_URL,
            content_id: EMAIL_LOGO_CONTENT_ID,
          },
        ],
      }),
    });

    const body = await response.json().catch(() => ({}));

    if (!response.ok) {
      const message =
        body?.message || body?.error || `Resend HTTP ${response.status}`;
      console.error("sendEmail failed:", {
        to,
        from,
        resendStatus: "failed",
        error: message,
        body,
      });
      return { ok: false, from, error: message };
    }

    console.log("sendEmail success:", {
      to,
      from,
      resendStatus: "sent",
      resendId: body?.id || null,
    });
    return { ok: true, from, id: body?.id };
  } catch (err) {
    console.error("sendEmail error:", { to, from, error: err });
    return { ok: false, from, error: err.message || "Email send failed" };
  }
}

/**
 * Optional delivery log for admin troubleshooting (no spiritual content).
 */
async function logEmailDelivery({
  type,
  to,
  from,
  ok,
  error,
  organizationId,
  inviteId,
  orgId,
  resendId,
}) {
  try {
    const db = getFirestore();
    const payload = {
      type,
      to,
      from: from || null,
      ok,
      resendStatus: ok ? "sent" : "failed",
      resendId: resendId || null,
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
