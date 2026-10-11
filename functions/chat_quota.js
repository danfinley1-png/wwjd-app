const { getFirestore, FieldValue } = require("firebase-admin/firestore");

/** Keep in sync with lib/core/config.dart */
const GUEST_LIFETIME_LIMIT = 3;
const REGISTERED_DAILY_LIMIT = 25;
const MIN_MS_BETWEEN_REQUESTS = 3000;

function isAnonymousAuth(decoded) {
  return decoded.firebase?.sign_in_provider === "anonymous";
}

function isAdmin(decoded) {
  return decoded.admin === true;
}

/** America/New_York civil day (yyyy-MM-dd). */
function newYorkDayKey(date = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/New_York",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function quotaFailure(status, code, message, extra = {}) {
  return {
    ok: false,
    status,
    body: {
      error: message,
      code,
      ...extra,
    },
  };
}

/**
 * Reserve one Ask WWJD / Delve Deeper call (transactional).
 * @returns {{ ok: true } | { ok: false, status: number, body: object }}
 */
async function consumeChatQuota(decoded) {
  if (isAdmin(decoded)) {
    return { ok: true };
  }

  const db = getFirestore();
  const uid = decoded.uid;
  const anon = isAnonymousAuth(decoded);
  const userRef = db.collection("users").doc(uid);
  const nowMs = Date.now();

  try {
    return await db.runTransaction(async (tx) => {
      if (anon) {
        const guestRef = userRef.collection("chatQuota").doc("guest");
        const snap = await tx.get(guestRef);
        const data = snap.exists ? snap.data() : {};
        const count = Number(data.count) || 0;
        const lastMs = data.lastRequestAt?.toMillis?.() ?? 0;

        if (nowMs - lastMs < MIN_MS_BETWEEN_REQUESTS) {
          return quotaFailure(
            429,
            "RATE_LIMIT",
            "Please wait a few seconds before sending another question.",
            { retryAfterSeconds: Math.ceil(MIN_MS_BETWEEN_REQUESTS / 1000) }
          );
        }
        if (count >= GUEST_LIFETIME_LIMIT) {
          return quotaFailure(
            429,
            "GUEST_LIMIT",
            "Guest limit reached. Sign in or register to continue asking WWJD.",
            {
              limit: GUEST_LIFETIME_LIMIT,
              used: count,
            }
          );
        }

        tx.set(
          guestRef,
          {
            count: count + 1,
            lastRequestAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        return {
          ok: true,
          remaining: GUEST_LIFETIME_LIMIT - count - 1,
          guest: true,
        };
      }

      const dayKey = newYorkDayKey();
      const dayRef = userRef.collection("chatQuota").doc("daily").collection("days").doc(dayKey);
      const snap = await tx.get(dayRef);
      const data = snap.exists ? snap.data() : {};
      const count = Number(data.count) || 0;
      const lastMs = data.lastRequestAt?.toMillis?.() ?? 0;

      if (nowMs - lastMs < MIN_MS_BETWEEN_REQUESTS) {
        return quotaFailure(
          429,
          "RATE_LIMIT",
          "Please wait a few seconds before sending another question.",
          { retryAfterSeconds: Math.ceil(MIN_MS_BETWEEN_REQUESTS / 1000) }
        );
      }
      if (count >= REGISTERED_DAILY_LIMIT) {
        return quotaFailure(
          429,
          "DAILY_LIMIT",
          "Daily question limit reached. You can ask again after midnight Eastern Time.",
          {
            limit: REGISTERED_DAILY_LIMIT,
            used: count,
            dayKey,
          }
        );
      }

      tx.set(
        dayRef,
        {
          count: count + 1,
          dayKey,
          lastRequestAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return {
        ok: true,
        remaining: REGISTERED_DAILY_LIMIT - count - 1,
        guest: false,
        dayKey,
      };
    });
  } catch (err) {
    console.error("consumeChatQuota error:", err);
    return quotaFailure(
      503,
      "QUOTA_UNAVAILABLE",
      "Could not verify question allowance. Please try again shortly."
    );
  }
}

module.exports = {
  consumeChatQuota,
  GUEST_LIFETIME_LIMIT,
  REGISTERED_DAILY_LIMIT,
  newYorkDayKey,
};
