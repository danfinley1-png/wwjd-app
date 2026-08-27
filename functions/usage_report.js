const { onRequest } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { verifyIdToken, isSuperAdmin } = require("./usage_report_auth");

function dayKey(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function parsePeriodDays(body) {
  const raw = body?.periodDays;
  if (raw === null || raw === undefined || raw === 0 || raw === "all") {
    return null;
  }
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) return 30;
  return Math.min(Math.floor(n), 3660);
}

function isRegisteredAuthUser(userRecord) {
  const providers = userRecord.providerData || [];
  if (providers.length === 0) return false;
  const onlyAnonymous =
    providers.length === 1 && providers[0].providerId === "anonymous";
  return !onlyAnonymous;
}

async function countAuthUsers(auth) {
  let totalRegistered = 0;
  let nextPageToken;
  do {
    const page = await auth.listUsers(1000, nextPageToken);
    for (const user of page.users) {
      if (isRegisteredAuthUser(user)) totalRegistered += 1;
    }
    nextPageToken = page.pageToken;
  } while (nextPageToken);
  return totalRegistered;
}

async function countNewRegistrations(auth, since) {
  let count = 0;
  let nextPageToken;
  do {
    const page = await auth.listUsers(1000, nextPageToken);
    for (const user of page.users) {
      if (!isRegisteredAuthUser(user)) continue;
      const created = user.metadata?.creationTime
        ? new Date(user.metadata.creationTime)
        : null;
      if (created && created >= since) count += 1;
    }
    nextPageToken = page.pageToken;
  } while (nextPageToken);
  return count;
}

async function countActiveRegisteredUsers(db, since) {
  try {
    const snap = await db
      .collection("users")
      .where("isAnonymous", "==", false)
      .where("lastActive", ">=", Timestamp.fromDate(since))
      .count()
      .get();
    return snap.data().count || 0;
  } catch (err) {
    const message = err?.message || "";
    if (message.includes("index") || err?.code === 9) {
      console.warn("Active user count skipped — Firestore index building:", message);
      return 0;
    }
    throw err;
  }
}

async function aggregateDailyDocs(db, startKey, endKey) {
  const snap = await db
    .collection("platformUsage")
    .doc("daily")
    .collection("days")
    .where("dateKey", ">=", startKey)
    .where("dateKey", "<=", endKey)
    .get();

  const totals = {
    totalSessionCount: 0,
    totalSessionDurationSeconds: 0,
    guestSessionsInPeriod: 0,
    sessionsByDevice: { desktop: 0, mobile: 0, tablet: 0 },
    sectionViews: {},
  };

  for (const doc of snap.docs) {
    const data = doc.data();
    totals.totalSessionCount += Number(data.sessionCount || 0);
    totals.totalSessionDurationSeconds += Number(
      data.sessionDurationSeconds || 0
    );
    totals.guestSessionsInPeriod += Number(data.guestSessions || 0);
    totals.sessionsByDevice.desktop += Number(data.sessionsDesktop || 0);
    totals.sessionsByDevice.mobile += Number(data.sessionsMobile || 0);
    totals.sessionsByDevice.tablet += Number(data.sessionsTablet || 0);

    const views = data.sectionViews || {};
    for (const [key, value] of Object.entries(views)) {
      totals.sectionViews[key] =
        (totals.sectionViews[key] || 0) + Number(value || 0);
    }
  }

  return totals;
}

function registerUsageReportFunctions(exports) {
  exports.getUsageReport = onRequest(
    { cors: true, invoker: "public" },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      try {
        const decoded = await verifyIdToken(req);
        const db = getFirestore();
        const auth = getAuth();

        if (!(await isSuperAdmin(db, decoded))) {
          res.status(403).json({ error: "Super Admin access required" });
          return;
        }

        const periodDays = parsePeriodDays(req.body);
        const now = new Date();
        const periodStart =
          periodDays == null
            ? new Date(2020, 0, 1)
            : new Date(now.getTime() - periodDays * 86400000);

        const startKey = dayKey(periodStart);
        const endKey = dayKey(now);

        const trackingSnap = await db
          .collection("platformUsage")
          .doc("meta")
          .collection("docs")
          .doc("tracking")
          .get();
        const trackingStartedAt =
          trackingSnap.exists && trackingSnap.data().trackingStartedAt
            ? trackingSnap.data().trackingStartedAt.toDate().toISOString()
            : null;

        const [
          totalRegisteredUsers,
          newRegistrationsInPeriod,
          activeUsers7Days,
          activeUsers30Days,
          engagement,
        ] = await Promise.all([
          countAuthUsers(auth),
          countNewRegistrations(auth, periodStart),
          countActiveRegisteredUsers(
            db,
            new Date(now.getTime() - 7 * 86400000)
          ),
          countActiveRegisteredUsers(
            db,
            new Date(now.getTime() - 30 * 86400000)
          ),
          aggregateDailyDocs(db, startKey, endKey),
        ]);

        res.status(200).json({
          trackingStartedAt,
          totalRegisteredUsers,
          newRegistrationsInPeriod,
          activeUsers7Days,
          activeUsers30Days,
          guestSessionsInPeriod: engagement.guestSessionsInPeriod,
          totalSessionCount: engagement.totalSessionCount,
          totalSessionDurationSeconds: engagement.totalSessionDurationSeconds,
          sessionsByDevice: engagement.sessionsByDevice,
          sectionViews: engagement.sectionViews,
          userMetricsFromAuth: true,
          note:
            "Aggregate metrics only. No conversation, reflection, or gift content is included.",
        });
      } catch (err) {
        res
          .status(err.status || 500)
          .json({ error: err.message || "Failed to load usage report" });
      }
    }
  );
}

module.exports = { registerUsageReportFunctions };
