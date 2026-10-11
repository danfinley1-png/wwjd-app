/**

 * Lists published feast saints and checks Storage objects behind media URLs.

 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "...\adminsdk.json"

 *   node functions/scripts/verify_feast_saints.js

 */

const admin = require("firebase-admin");

const fs = require("fs");

const path = require("path");

const {

  storagePathFromDownloadUrl,

  DEFAULT_BUCKET,

} = require("./feast_saint_media_urls");



const DEFAULT_PROJECT_ID = "wwjd-di-e36ce";

const ARCHANGELS_FOLDER = "Saints/2026-09-29-Archangels/";



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

const bucket = admin.storage().bucket(DEFAULT_BUCKET);



function len(url) {

  if (typeof url !== "string") return 0;

  return url.trim().length;

}



async function objectExists(objectPath) {

  const file = bucket.file(objectPath);

  const [exists] = await file.exists();

  return exists;

}



async function checkMediaField(label, url) {

  const trimmed = (url || "").trim();

  if (!trimmed) {

    console.log("    " + label + ": (missing)");

    return true;

  }

  const objectPath = storagePathFromDownloadUrl(trimmed);

  if (!objectPath) {

    console.log("    " + label + ": not a Firebase download URL (len=" + trimmed.length + ")");

    return false;

  }

  const exists = await objectExists(objectPath);

  const status = exists ? "OK" : "404 — object missing in Storage";

  console.log("    " + label + ": " + status);

  console.log("      path: " + objectPath);

  if (objectPath.includes("2026-09-29-holy-archangels")) {

    console.log(

      "      FIX: re-seed with gs://.../Saints/2026-09-29-Archangels/... (folder is Archangels, not holy-archangels)"

    );

  }

  return exists;

}



async function main() {

  const snap = await db.collection("saints").where("published", "==", true).get();

  if (snap.empty) {

    console.log("No documents with published:true in saints/");

    process.exit(1);

  }

  console.log("Published feast saints (" + snap.size + "):\n");

  let allOk = true;

  for (const doc of snap.docs) {

    const d = doc.data();

    console.log("  saints/" + doc.id);

    console.log("    slug: " + (d.slug || "(missing)"));

    console.log("    name: " + (d.name || ""));

    console.log(

      "    feast: " + d.feastMonth + "/" + d.feastDay + " sortDate=" + d.sortDate

    );

    if (doc.id === "holy-archangels") {

      allOk =

        (await checkMediaField("videoPortraitUrl", d.videoPortraitUrl)) && allOk;

      allOk =

        (await checkMediaField("videoLandscapeUrl", d.videoLandscapeUrl)) && allOk;

      allOk =

        (await checkMediaField("posterPortraitUrl", d.posterPortraitUrl)) && allOk;

    } else {

      console.log("    videoPortraitUrl len=" + len(d.videoPortraitUrl));

      console.log("    videoLandscapeUrl len=" + len(d.videoLandscapeUrl));

      console.log("    posterPortraitUrl len=" + len(d.posterPortraitUrl));

    }

    console.log("");

  }



  const arch = snap.docs.find((d) => d.id === "holy-archangels");

  if (!arch) {

    console.error(

      "MISSING: saints/holy-archangels — run .\\scripts\\seed-holy-archangels.ps1 with ARCHANGELS_* gs:// URLs."

    );

    process.exit(1);

  }

  const a = arch.data();

  if (!len(a.videoPortraitUrl) && !len(a.videoLandscapeUrl)) {

    console.error("holy-archangels has no video URLs — re-run seed with gs:// paths.");

    process.exit(1);

  }

  if (!allOk) {

    console.error(

      "\nStorage 404: Firestore URLs do not match uploaded files.\n" +

        "Expected folder: " +

        ARCHANGELS_FOLDER +

        "\nRe-run .\\scripts\\seed-holy-archangels.ps1 with the three gs:// paths from tool/feast_saint_firestore_urls.md"

    );

    process.exit(1);

  }

  console.log("holy-archangels OK (published + Storage objects exist).");

}



main().catch((e) => {

  console.error(e.message || e);

  process.exit(1);

});


