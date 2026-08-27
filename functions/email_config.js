const { defineSecret, defineString } = require("firebase-functions/params");

/** Resend API key — set with: firebase functions:secrets:set RESEND_API_KEY */
const resendApiKey = defineSecret("RESEND_API_KEY");

/**
 * Verified sender for Resend (must match a verified domain in Resend).
 * Override in functions/.env for local deploy, e.g.:
 * EMAIL_FROM="WWJD-DI <hello@yourdomain.com>"
 */
const emailFrom = defineString("EMAIL_FROM", {
  default: "WWJD-DI <onboarding@resend.dev>",
});

/** Public web app origin for links in emails. */
const appBaseUrl = defineString("APP_BASE_URL", {
  default: "https://wwjd-di-e36ce.web.app",
});

function appUrl(path = "/") {
  const base = appBaseUrl.value().replace(/\/+$/, "");
  const normalized = path.startsWith("/") ? path : `/${path}`;
  return `${base}${normalized}`;
}

module.exports = {
  resendApiKey,
  emailFrom,
  appBaseUrl,
  appUrl,
};
