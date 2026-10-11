/**
 * Merge validated Storage download URLs onto existing saints/{id} docs.
 * Holy Archangels: ARCHANGELS_VIDEO_LANDSCAPE_URL, ARCHANGELS_VIDEO_PORTRAIT_URL,
 * ARCHANGELS_POSTER_PORTRAIT_URL — or run seed_holy_archangels.js
 */
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const {
  isValidFirestoreMediaUrl,
  readHolyArchangelsMediaUrls,
} = require("./feast_saint_media_urls");

const DEFAULT_PROJECT_ID = "wwjd-di-e36ce";

function resolveProjectId() {
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  try {
    const raw = fs.readFileSync(
      path.join(__dirname, "..", "..", ".firebaserc"),
      "utf8"
    );
    return JSON.parse(raw)?.projects?.default || DEFAULT_PROJECT_ID;
  } catch (_) {
    return DEFAULT_PROJECT_ID;
  }
}

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: resolveProjectId() });
}

const db = admin.firestore();

function usable(url, name) {
  const r = isValidFirestoreMediaUrl(url, name);
  return r.ok ? r.value : null;
}

async function main() {
  let any = false;

  const claverUpdate = {};
  const cp = usable(
    process.env.CLAVER_PORTRAIT_URL || process.env.CLaver_PORTRAIT_URL,
    "CLAVER_PORTRAIT_URL"
  );
  const cl = usable(
    process.env.CLAVER_LANDSCAPE_URL || process.env.CLaver_LANDSCAPE_URL,
    "CLAVER_LANDSCAPE_URL"
  );
  const cpo = usable(
    process.env.CLAVER_POSTER_URL || process.env.CLaver_POSTER_URL,
    "CLAVER_POSTER_URL"
  );
  if (cp) claverUpdate.videoPortraitUrl = cp;
  if (cl) claverUpdate.videoLandscapeUrl = cl;
  if (cpo) claverUpdate.posterPortraitUrl = cpo;
  if (Object.keys(claverUpdate).length > 0) {
    await db.collection("saints").doc("peter-claver").set(claverUpdate, { merge: true });
    console.log("Patched saints/peter-claver");
    any = true;
  }

  const pioUpdate = {};
  const pp = usable(process.env.PIO_PORTRAIT_URL, "PIO_PORTRAIT_URL");
  const pl = usable(process.env.PIO_LANDSCAPE_URL, "PIO_LANDSCAPE_URL");
  const ppo = usable(process.env.PIO_POSTER_URL, "PIO_POSTER_URL");
  if (pp) pioUpdate.videoPortraitUrl = pp;
  if (pl) pioUpdate.videoLandscapeUrl = pl;
  if (ppo) pioUpdate.posterPortraitUrl = ppo;
  if (Object.keys(pioUpdate).length > 0) {
    await db.collection("saints").doc("pio-pietrelcina").set(pioUpdate, { merge: true });
    console.log("Patched saints/pio-pietrelcina");
    any = true;
  }

  const arch = await readHolyArchangelsMediaUrls(admin.storage());
  if (arch.ok) {
    const update = {
      videoLandscapeUrl: arch.videoLandscapeUrl,
      videoPortraitUrl: arch.videoPortraitUrl,
      posterPortraitUrl: arch.posterPortraitUrl,
    };
    await db.collection("saints").doc("holy-archangels").set(update, { merge: true });
    console.log("Patched saints/holy-archangels");
    console.log("videoLandscapeUrl:", update.videoLandscapeUrl);
    console.log("videoPortraitUrl:", update.videoPortraitUrl);
    console.log("posterPortraitUrl:", update.posterPortraitUrl);
    any = true;
  }

  if (!any) {
    console.error("No valid https URLs in env. For Archangels use seed_holy_archangels.js");
    process.exit(1);
  }
  console.log("Done.");
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
