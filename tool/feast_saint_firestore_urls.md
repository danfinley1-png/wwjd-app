# Feast saint Firestore URLs

Firestore fields `videoPortraitUrl`, `videoLandscapeUrl`, and `posterPortraitUrl` must be **full Firebase Storage download URLs** from the Console (https, with `alt=media&token=…`). Never `gs://`, never placeholder text, never partial paths.

## Holy Archangels — fix bad seed / playback

If the app shows `GoException` for `/PASTE_…`, Firestore has placeholder URLs. **Re-seed with real Console links only.**

**Storage layout (must match uploaded folder name — case matters):**

- `Saints/2026-09-29-Archangels/landscape.mp4` (16:9)
- `Saints/2026-09-29-Archangels/portrait.mp4` (9:16)
- `Saints/2026-09-29-Archangels/poster.jpg`

Firestore slug stays `holy-archangels`; only the **Storage folder** uses `Archangels`. URLs that say `2026-09-29-holy-archangels` in the path return **404** from `firebasestorage.googleapis.com`.

**Get https URLs from `gs://` paths** (service account required):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\wwjd-di-e36ce-firebase-adminsdk.json"
node functions/scripts/storage_download_url.js "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-09-29-Archangels/landscape.mp4"
node functions/scripts/storage_download_url.js "Saints/2026-09-29-Archangels/portrait.mp4"
node functions/scripts/storage_download_url.js "Saints/2026-09-29-Archangels/poster.jpg"
```

Copy each printed line into the env vars below (or use Console → Copy download URL).

**Required env vars** (each value must be a full `https://firebasestorage.googleapis.com/...` line):

| Variable | Field in Firestore |
|----------|-------------------|
| `ARCHANGELS_VIDEO_LANDSCAPE_URL` | `videoLandscapeUrl` |
| `ARCHANGELS_VIDEO_PORTRAIT_URL` | `videoPortraitUrl` (optional; defaults to landscape) |
| `ARCHANGELS_POSTER_PORTRAIT_URL` | `posterPortraitUrl` |

Each env var may be a full **https** download URL or a **`gs://`** path (seed script resolves via Admin SDK). Scripts refuse placeholders (`PASTE_`, `TODO`) and missing objects.

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\wwjd-di-e36ce-firebase-adminsdk.json"
$env:ARCHANGELS_VIDEO_LANDSCAPE_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-09-29-Archangels/landscape.mp4"
$env:ARCHANGELS_VIDEO_PORTRAIT_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-09-29-Archangels/portrait.mp4"
$env:ARCHANGELS_POSTER_PORTRAIT_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-09-29-Archangels/poster.jpg"
cd C:\Users\danfi\wwjd_app
.\scripts\seed-holy-archangels.ps1
```

Output must print three lines starting with `https://firebasestorage.googleapis.com/`.

Verify:

```powershell
node functions/scripts/verify_feast_saints.js
```

Deploy stream proxy after path changes: `firebase deploy --only functions:streamSaintVideo`

## St. Faustina Kowalska

Firestore document: `saints/faustina` (route `/saints/faustina`). Feast **October 5** (`feastMonth` 10, `feastDay` 5, `sortDate` `2026-10-05`), rank `optional memorial`.

**Storage folder:** `Saints/2026-10-05-faustina/`

| Object | Env | Firestore field |
|--------|-----|-----------------|
| `landscape.mp4` | `FAUSTINA_VIDEO_LANDSCAPE_URL` | `videoLandscapeUrl` |
| `portrait.mp4` | `FAUSTINA_VIDEO_PORTRAIT_URL` | `videoPortraitUrl` |
| `poster.png` | `FAUSTINA_POSTER_PORTRAIT_URL` | `posterPortraitUrl` |

All three are required. Each env value may be a full **https** download URL or a **`gs://`** path. The seed resolves `gs://` with the Admin SDK and writes **download URLs only**. It refuses the Faustina write (exit 1) if any URL is missing, is still `gs://`, or contains `PASTE`.

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\wwjd-di-e36ce-firebase-adminsdk.json"
$env:FAUSTINA_VIDEO_LANDSCAPE_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/landscape.mp4"
$env:FAUSTINA_VIDEO_PORTRAIT_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/portrait.mp4"
$env:FAUSTINA_POSTER_PORTRAIT_URL = "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/poster.png"
cd C:\Users\danfi\wwjd_app
.\scripts\seed-feast-saints.ps1
```

`.\scripts\seed-feast-saints.ps1` sets those three `gs://` paths when the env vars are unset. Output for Faustina must print three lines starting with `https://firebasestorage.googleapis.com/`.

Resolve one object first:

```powershell
node functions/scripts/storage_download_url.js "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/landscape.mp4"
node functions/scripts/storage_download_url.js "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/portrait.mp4"
node functions/scripts/storage_download_url.js "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-10-05-faustina/poster.png"
```

## Claver / Pio (legacy env names)

| Env | Field |
|-----|--------|
| `CLAVER_PORTRAIT_URL` | `videoPortraitUrl` |
| `CLAVER_LANDSCAPE_URL` | `videoLandscapeUrl` (optional) |
| `CLAVER_POSTER_URL` | `posterPortraitUrl` |
| `PIO_PORTRAIT_URL` | `videoPortraitUrl` |
| `PIO_LANDSCAPE_URL` | `videoLandscapeUrl` (optional) |
| `PIO_POSTER_URL` | `posterPortraitUrl` |

Partial URL updates: `.\scripts\patch-feast-saint-urls.ps1` (same https rules for Archangels).
