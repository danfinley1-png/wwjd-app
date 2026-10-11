/**

 * Feast-day saint films (Claver, Pio, Holy Archangels, St. Faustina).

 *

 * Holy Archangels requires validated https download URLs:

 *   ARCHANGELS_VIDEO_LANDSCAPE_URL

 *   ARCHANGELS_VIDEO_PORTRAIT_URL (optional — defaults to landscape)

 *   ARCHANGELS_POSTER_PORTRAIT_URL

 *

 * Or run only Archangels: node functions/scripts/seed_holy_archangels.js

 *

 * St. Faustina (saints/faustina, October 5) — all three required:

 *   FAUSTINA_VIDEO_LANDSCAPE_URL

 *   FAUSTINA_VIDEO_PORTRAIT_URL

 *   FAUSTINA_POSTER_PORTRAIT_URL

 * gs:// is resolved to a download URL. Missing, leftover gs://, or PASTE refuses the seed.

 */

const admin = require("firebase-admin");

const fs = require("fs");

const path = require("path");

const {

  isValidFirestoreMediaUrl,

  readFaustinaMediaUrls,

  readHolyArchangelsMediaUrls,

} = require("./feast_saint_media_urls");



const DEFAULT_PROJECT_ID = "wwjd-di-e36ce";



function resolveProjectId() {

  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;

  if (process.env.GOOGLE_CLOUD_PROJECT) return process.env.GOOGLE_CLOUD_PROJECT;

  try {

    const firebasercPath = path.join(__dirname, "..", "..", ".firebaserc");

    const raw = fs.readFileSync(firebasercPath, "utf8");

    const parsed = JSON.parse(raw);

    const id = parsed?.projects?.default;

    if (id && typeof id === "string") return id;

  } catch (_) {

    // fall through

  }

  return DEFAULT_PROJECT_ID;

}



if (admin.apps.length === 0) {

  admin.initializeApp({ projectId: resolveProjectId() });

}



const db = admin.firestore();



const STORAGE = {

  claverPortrait:

    process.env.CLAVER_PORTRAIT_URL || process.env.CLaver_PORTRAIT_URL || "",

  claverLandscape:

    process.env.CLAVER_LANDSCAPE_URL || process.env.CLaver_LANDSCAPE_URL || "",

  claverPoster:

    process.env.CLAVER_POSTER_URL || process.env.CLaver_POSTER_URL || "",

  pioPortrait: process.env.PIO_PORTRAIT_URL || "",

  pioLandscape: process.env.PIO_LANDSCAPE_URL || "",

  pioPoster: process.env.PIO_POSTER_URL || "",

};



function claverReady() {

  const p = isValidFirestoreMediaUrl(STORAGE.claverPortrait, "CLAVER_PORTRAIT_URL");

  const poster = isValidFirestoreMediaUrl(STORAGE.claverPoster, "CLAVER_POSTER_URL");

  return p.ok && poster.ok ? { ok: true, portrait: p.value, poster: poster.value } : { ok: false };

}



function pioReady() {

  const p = isValidFirestoreMediaUrl(STORAGE.pioPortrait, "PIO_PORTRAIT_URL");

  const poster = isValidFirestoreMediaUrl(STORAGE.pioPoster, "PIO_POSTER_URL");

  if (!p.ok || !poster.ok) return { ok: false };

  let landscape = null;

  if (STORAGE.pioLandscape.trim()) {

    const l = isValidFirestoreMediaUrl(STORAGE.pioLandscape, "PIO_LANDSCAPE_URL");

    if (l.ok) landscape = l.value;

  }

  return { ok: true, portrait: p.value, poster: poster.value, landscape };

}



const pioCaptions = [

  { startSec: 0, endSec: 12, text: "Pray, hope, and don't worry." },

  { startSec: 12, endSec: 24, text: "God is greater than our hearts." },

  { startSec: 24, endSec: 36, text: "Stay close to the sacraments." },

  { startSec: 36, endSec: 48, text: "From dawn I sat in the confessional. Souls came and received God's mercy." },

  { startSec: 48, endSec: 60, text: "The Lord uses small instruments." },

  { startSec: 60, endSec: 72, text: "Offer your day for others." },

  { startSec: 72, endSec: 84, text: "Peace comes from trust in Christ." },

  { startSec: 84, endSec: 96, text: "St. Pio of Pietrelcina, pray for us." },

];



function holyArchangelsDoc(media) {

  return {

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

    videoPortraitUrl: media.videoPortraitUrl,

    videoLandscapeUrl: media.videoLandscapeUrl,

    posterPortraitUrl: media.posterPortraitUrl,

    posterLandscapeUrl: null,

    captions: [],

    published: true,

    sortDate: "2026-09-29",

  };

}



function faustinaDoc(media) {

  return {

    slug: "faustina",

    name: "St. Faustina Kowalska",

    feastMonth: 10,

    feastDay: 5,

    rank: "optional memorial",

    quote: "Jesus, I trust in You.",

    patronage: "Divine Mercy",

    prayLine: "Saint Faustina, pray for us.",

    durationSec: 90,

    videoPortraitUrl: media.videoPortraitUrl,

    videoLandscapeUrl: media.videoLandscapeUrl,

    posterPortraitUrl: media.posterPortraitUrl,

    posterLandscapeUrl: null,

    captions: [],

    published: true,

    sortDate: "2026-10-05",

  };

}



async function main() {

  let wrote = false;



  const claver = claverReady();

  if (claver.ok) {
    let claverLandscape = null;
    if (STORAGE.claverLandscape.trim()) {
      const lv = isValidFirestoreMediaUrl(
        STORAGE.claverLandscape,
        "CLAVER_LANDSCAPE_URL"
      );
      if (lv.ok) claverLandscape = lv.value;
    }

    await db.collection("saints").doc("peter-claver").set(

      {

        slug: "peter-claver",

        name: "St. Peter Claver",

        feastMonth: 9,

        feastDay: 9,

        rank: "memorial",

        quote:

          "We must speak to them with our hands before we speak with our lips.",

        patronage:

          "Missions, the enslaved, the African diaspora, Colombia, and all who serve the forgotten.",

        prayLine: "St. Peter Claver, pray for us.",

        durationSec: 90,

        videoPortraitUrl: claver.portrait,

        videoLandscapeUrl: claverLandscape,

        posterPortraitUrl: claver.poster,

        posterLandscapeUrl: null,

        captions: [],

        published: true,

        sortDate: "2026-09-09",

      },

      { merge: true }

    );

    console.log("Seeded saints/peter-claver");

    wrote = true;

  } else {

    console.log("Skip saints/peter-claver (invalid or missing CLAVER_* URLs)");

  }



  const pio = pioReady();

  if (pio.ok) {

    await db.collection("saints").doc("pio-pietrelcina").set(

      {

        slug: "pio-pietrelcina",

        name: "St. Pio of Pietrelcina",

        feastMonth: 9,

        feastDay: 23,

        rank: "memorial",

        quote: "Pray, hope, and don't worry.",

        patronage:

          "The anxious, the young, those who keep watch, and all who serve in hidden ways.",

        prayLine: "St. Pio of Pietrelcina, pray for us.",

        durationSec: 96,

        videoPortraitUrl: pio.portrait,

        videoLandscapeUrl: pio.landscape,

        posterPortraitUrl: pio.poster,

        posterLandscapeUrl: null,

        captions: pioCaptions,

        published: true,

        sortDate: "2026-09-23",

      },

      { merge: true }

    );

    console.log("Seeded saints/pio-pietrelcina");

    wrote = true;

  } else {

    console.log("Skip saints/pio-pietrelcina (invalid or missing PIO_* URLs)");

  }



  const archMedia = await readHolyArchangelsMediaUrls(admin.storage());

  if (archMedia.ok) {

    const data = holyArchangelsDoc(archMedia);

    await db.collection("saints").doc("holy-archangels").set(data, { merge: true });

    console.log("Seeded saints/holy-archangels");

    console.log("videoLandscapeUrl:", data.videoLandscapeUrl);

    console.log("videoPortraitUrl:", data.videoPortraitUrl);

    console.log("posterPortraitUrl:", data.posterPortraitUrl);

    wrote = true;

  } else {

    console.log("Skip saints/holy-archangels — " + archMedia.error);

  }



  const faustinaMedia = await readFaustinaMediaUrls(admin.storage());

  if (!faustinaMedia.ok) {

    console.error("Refusing saints/faustina: " + faustinaMedia.error);

    process.exit(1);

  }



  const faustina = faustinaDoc(faustinaMedia);

  await db.collection("saints").doc("faustina").set(faustina, { merge: true });

  console.log("Seeded saints/faustina");

  console.log("videoLandscapeUrl:", faustina.videoLandscapeUrl);

  console.log("videoPortraitUrl:", faustina.videoPortraitUrl);

  console.log("posterPortraitUrl:", faustina.posterPortraitUrl);

  wrote = true;



  if (!wrote) {

    console.error(

      "Nothing seeded. For Archangels set ARCHANGELS_VIDEO_* env vars " +

        "(see tool/feast_saint_firestore_urls.md) or run seed_holy_archangels.js. " +

        "Faustina uses FAUSTINA_VIDEO_* (gs:// is resolved; gs:// and PASTE are never written)."

    );

    process.exit(1);

  }

  console.log("Done.");

}



main().catch((err) => {

  console.error(err.message || err);

  process.exit(1);

});


