const { defineSecret, defineString } = require("firebase-functions/params");

/** Resend API key — set with: firebase functions:secrets:set RESEND_API_KEY */
const resendApiKey = defineSecret("RESEND_API_KEY");

/**
 * Verified Resend sender. Hardcoded so a leftover EMAIL_FROM param
 * (onboarding@resend.dev) cannot override production mail.
 */
const EMAIL_FROM = "WWJD-DI <noreply@contact.wwjddi.com>";

/**
 * App mark for email clients (PWA icon on Firebase Hosting — absolute https).
 * Same crucifix used in the header crop and Add to Home Screen icon.
 */
const EMAIL_LOGO_URL = "https://wwjd-di-e36ce.web.app/icons/Icon-192.png";
const EMAIL_LOGO_CONTENT_ID = "wwjd-di-logo";

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
  EMAIL_FROM,
  EMAIL_LOGO_URL,
  EMAIL_LOGO_CONTENT_ID,
  appBaseUrl,
  appUrl,
};
