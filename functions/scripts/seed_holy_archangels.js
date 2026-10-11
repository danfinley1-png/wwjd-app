/**
 * Writes only saints/holy-archangels with validated https Storage download URLs.
 *
 * Required env — https download URL **or** gs:// object path for each:
 *   ARCHANGELS_VIDEO_LANDSCAPE_URL
 *   ARCHANGELS_VIDEO_PORTRAIT_URL  (optional — defaults to landscape)
 *   ARCHANGELS_POSTER_PORTRAIT_URL
 *
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "...\adminsdk.json"
 *   node functions/scripts/seed_holy_archangels.js
 */
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const { readHolyArchangelsMediaUrls } = require("./feast_saint_media_urls");

const DEFAULT_PROJECT_ID = "wwjd-di-e36ce";

function resolveProjectId() {
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  if (process.env.GOOGLE_CLOUD_PROJECT) return process.env.GOOGLE_CLOUD_PROJECT;
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

const HOLY_ARCHANGELS_DOC = {
  slug: "holy-archangels",
  name: "Saints Michael, Gabriel, and Raphael",
  feastMonth: 9,
  feastDay: 29,
  rank: "feast",
  quote:
    "Michael, help us in our battle. Gabriel, bring us the good news of salvation. Raphael, take us by the hand and lead us forward.",
  patronage:
    "Michael: the Church, those who stand guard, the dying, and those in spiritual battle. Gabriel: messengers and those who must speak a holy word. Raphael: travelers, the sick, and those who nurse them.",
  prayLine: "Saints Michael, Gabriel, and Raphael, pray for us.",
  durationSec: 74,
  posterLandscapeUrl: null,
  captions: [],
  published: true,
  sortDate: "2026-09-29",
};

async function main() {
  const media = await readHolyArchangelsMediaUrls(admin.storage());
  if (!media.ok) {
    console.error("Refusing to write Firestore: " + media.error);
    console.error(
      "\nSet ARCHANGELS_VIDEO_* to gs://... or https://firebasestorage.googleapis.com/..."
    );
    process.exit(1);
  }

  const data = {
    ...HOLY_ARCHANGELS_DOC,
    videoLandscapeUrl: media.videoLandscapeUrl,
    videoPortraitUrl: media.videoPortraitUrl,
    posterPortraitUrl: media.posterPortraitUrl,
  };

  await db.collection("saints").doc("holy-archangels").set(data, { merge: true });

  console.log("Seeded saints/holy-archangels");
  console.log("videoLandscapeUrl:", data.videoLandscapeUrl);
  console.log("videoPortraitUrl:", data.videoPortraitUrl);
  console.log("posterPortraitUrl:", data.posterPortraitUrl);
  console.log("Done.");
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
