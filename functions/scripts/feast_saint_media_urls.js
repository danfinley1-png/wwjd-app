/** Validates Firebase Storage download URLs; resolves gs:// to https for seed scripts. */
const FIREBASE_STORAGE_PREFIX = "https://firebasestorage.googleapis.com/";
const DEFAULT_BUCKET = "wwjd-di-e36ce.firebasestorage.app";

const PLACEHOLDER_MARKERS = ["PASTE_", "TODO", "YOUR_TOKEN"];

function isValidFirestoreMediaUrl(raw, envName) {
  if (typeof raw !== "string") {
    return { ok: false, error: `${envName} is not set` };
  }
  const url = raw.trim();
  if (url.length === 0) {
    return { ok: false, error: `${envName} is empty` };
  }
  if (url.startsWith("gs://") || (url.startsWith("/") && !url.startsWith("http"))) {
    return {
      ok: false,
      error: `${envName} must be resolved to https (use gs:// with seed_holy_archangels.js)`,
    };
  }
  if (!url.startsWith(FIREBASE_STORAGE_PREFIX)) {
    return {
      ok: false,
      error: `${envName} must start with ${FIREBASE_STORAGE_PREFIX}`,
    };
  }
  if (!url.includes("alt=media")) {
    return {
      ok: false,
      error: `${envName} must be a Firebase download URL (include alt=media)`,
    };
  }
  const upper = url.toUpperCase();
  for (const marker of PLACEHOLDER_MARKERS) {
    if (upper.includes(marker.toUpperCase())) {
      return { ok: false, error: `${envName} looks like a placeholder` };
    }
  }
  return { ok: true, value: url };
}

function parseStorageReference(raw) {
  const trimmed = raw.trim();
  if (trimmed.startsWith("gs://")) {
    const without = trimmed.slice("gs://".length);
    const slash = without.indexOf("/");
    if (slash <= 0) return null;
    return {
      bucket: without.slice(0, slash),
      objectPath: without.slice(slash + 1),
    };
  }
  if (
    trimmed.startsWith("Saints/") ||
    trimmed.startsWith("saints/")
  ) {
    return { bucket: DEFAULT_BUCKET, objectPath: trimmed };
  }
  return null;
}

function buildDownloadUrl(bucketName, objectPath, token) {
  const encoded = encodeURIComponent(objectPath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}?alt=media&token=${token}`;
}

function storagePathFromDownloadUrl(url) {
  try {
    const u = new URL(url.trim());
    if (!u.hostname.includes("firebasestorage.googleapis.com")) return null;
    const m = u.pathname.match(/^\/v0\/b\/[^/]+\/o\/(.+)$/);
    if (!m) return null;
    return decodeURIComponent(m[1]);
  } catch (_) {
    return null;
  }
}

async function resolveMediaInput(raw, envName, adminStorage) {
  const trimmed = (raw || "").trim();
  if (!trimmed) {
    return { ok: false, error: `${envName} is not set` };
  }
  if (trimmed.startsWith("https://")) {
    return isValidFirestoreMediaUrl(trimmed, envName);
  }

  const ref = parseStorageReference(trimmed);
  if (!ref) {
    return isValidFirestoreMediaUrl(trimmed, envName);
  }

  const bucket = adminStorage.bucket(ref.bucket);
  const file = bucket.file(ref.objectPath);
  const [exists] = await file.exists();
  if (!exists) {
    return {
      ok: false,
      error: `${envName}: object not found gs://${ref.bucket}/${ref.objectPath}`,
    };
  }
  const [meta] = await file.getMetadata();
  let token = meta.metadata?.firebaseStorageDownloadTokens;
  if (typeof token === "string" && token.includes(",")) {
    token = token.split(",")[0].trim();
  }
  if (!token) {
    return {
      ok: false,
      error: `${envName}: no download token — use Firebase Console Copy download URL`,
    };
  }
  const url = buildDownloadUrl(ref.bucket, ref.objectPath, token);
  return isValidFirestoreMediaUrl(url, envName);
}

/** Firestore may store only https download URLs — never gs:// or PASTE placeholders. */
function finalMediaUrlOrRefuse(url, envName) {
  if (typeof url !== "string" || url.trim().length === 0) {
    return { ok: false, error: `${envName} is missing` };
  }
  const value = url.trim();
  if (value.startsWith("gs://")) {
    return { ok: false, error: `${envName} is gs://` };
  }
  if (value.toUpperCase().includes("PASTE")) {
    return { ok: false, error: `${envName} contains PASTE` };
  }
  return isValidFirestoreMediaUrl(value, envName);
}

const FAUSTINA_STORAGE = {
  landscape:
    "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/landscape.mp4",
  portrait:
    "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/portrait.mp4",
  poster:
    "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/poster.png",
};

/**
 * St. Faustina. Env may be gs:// or https; the returned fields are download URLs only.
 * Missing, unresolved gs://, or PASTE refuses the seed.
 */
async function readFaustinaMediaUrls(adminStorage) {
  const specs = [
    [
      process.env.FAUSTINA_VIDEO_LANDSCAPE_URL || FAUSTINA_STORAGE.landscape,
      "FAUSTINA_VIDEO_LANDSCAPE_URL",
      "videoLandscapeUrl",
    ],
    [
      process.env.FAUSTINA_VIDEO_PORTRAIT_URL || FAUSTINA_STORAGE.portrait,
      "FAUSTINA_VIDEO_PORTRAIT_URL",
      "videoPortraitUrl",
    ],
    [
      process.env.FAUSTINA_POSTER_PORTRAIT_URL || FAUSTINA_STORAGE.poster,
      "FAUSTINA_POSTER_PORTRAIT_URL",
      "posterPortraitUrl",
    ],
  ];

  const resolved = {};
  for (const [raw, envName, field] of specs) {
    if (typeof raw !== "string" || raw.trim().length === 0) {
      return { ok: false, error: `${envName} is missing` };
    }
    if (raw.toUpperCase().includes("PASTE")) {
      return { ok: false, error: `${envName} contains PASTE` };
    }

    const media = await resolveMediaInput(raw, envName, adminStorage);
    if (!media.ok) return { ok: false, error: media.error };

    const checked = finalMediaUrlOrRefuse(media.value, envName);
    if (!checked.ok) return { ok: false, error: checked.error };
    resolved[field] = checked.value;
  }

  return { ok: true, ...resolved };
}

async function readHolyArchangelsMediaUrls(adminStorage) {
  const landscapeRaw = process.env.ARCHANGELS_VIDEO_LANDSCAPE_URL || "";
  const portraitRaw = process.env.ARCHANGELS_VIDEO_PORTRAIT_URL || "";
  const posterRaw = process.env.ARCHANGELS_POSTER_PORTRAIT_URL || "";

  const landscape = await resolveMediaInput(
    landscapeRaw,
    "ARCHANGELS_VIDEO_LANDSCAPE_URL",
    adminStorage
  );
  if (!landscape.ok) return { ok: false, error: landscape.error };

  const portraitSource =
    portraitRaw.trim().length > 0 ? portraitRaw : landscapeRaw || landscape.value;
  const portrait = await resolveMediaInput(
    portraitSource,
    portraitRaw.trim().length > 0
      ? "ARCHANGELS_VIDEO_PORTRAIT_URL"
      : "ARCHANGELS_VIDEO_PORTRAIT_URL (defaults to landscape)",
    adminStorage
  );
  if (!portrait.ok) return { ok: false, error: portrait.error };

  const poster = await resolveMediaInput(
    posterRaw,
    "ARCHANGELS_POSTER_PORTRAIT_URL",
    adminStorage
  );
  if (!poster.ok) return { ok: false, error: poster.error };

  return {
    ok: true,
    videoLandscapeUrl: landscape.value,
    videoPortraitUrl: portrait.value,
    posterPortraitUrl: poster.value,
  };
}

module.exports = {
  isValidFirestoreMediaUrl,
  finalMediaUrlOrRefuse,
  readFaustinaMediaUrls,
  readHolyArchangelsMediaUrls,
  resolveMediaInput,
  storagePathFromDownloadUrl,
  buildDownloadUrl,
  FAUSTINA_STORAGE,
  FIREBASE_STORAGE_PREFIX,
  DEFAULT_BUCKET,
};
