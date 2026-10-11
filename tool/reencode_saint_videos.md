# Re-encode saint videos for web / PWA playback

Browsers (Chrome, Edge, Safari) require **H.264 (avc1) + AAC** in an `.mp4` container, ideally **`yuv420p`** (not `yuvj420p` full-range if you can avoid it).

WWJD-DI **web/PWA** plays feast films from the same Firebase **download URLs** as the poster (iframe). Native apps use the stream proxy with Range requests. Run `scripts/apply-storage-cors.ps1` if a browser build ever hits CORS on Storage.

Keep feast clips **under ~30 MB** when possible (Pio portrait is ~24 MB). Files **~100 MB+** can fail in the app stream proxy on a full download; re-export with a slightly higher CRF (e.g. `-crf 23`) or lower resolution.

CapCut and many phone exports use **HEVC (H.265)**, which triggers:

`MEDIA_ERR_SRC_NOT_SUPPORTED` / `FFmpegDemuxer: open context failed`

## FFmpeg (recommended)

Install [FFmpeg](https://ffmpeg.org/download.html), then for each file:

```powershell
ffmpeg -i "pio-9x16.mp4" -c:v libx264 -profile:v high -level 4.1 -pix_fmt yuv420p -crf 20 -c:a aac -b:a 128k -movflags +faststart "pio-9x16-h264.mp4"
```

`-movflags +faststart` moves metadata to the start so streaming works better.

Re-upload to Storage (replace the object):

```powershell
$gcloud = "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
& $gcloud storage cp --content-type="video/mp4" "pio-9x16-h264.mp4" "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-09-23-pio-pietrelcina/portrait.mp4"
```

Holy Archangels (example — both orientations):

```powershell
ffmpeg -i "arch-portrait-src.mp4" -c:v libx264 -profile:v high -level 4.1 -pix_fmt yuv420p -crf 23 -c:a aac -b:a 128k -movflags +faststart "arch-portrait-h264.mp4"
& $gcloud storage cp --content-type="video/mp4" "arch-portrait-h264.mp4" "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-09-29-Archangels/portrait.mp4"
& $gcloud storage cp --content-type="video/mp4" "arch-landscape-h264.mp4" "gs://wwjd-di-e36ce.firebasestorage.app/Saints/2026-09-29-Archangels/landscape.mp4"
```

Then re-run `.\scripts\seed-holy-archangels.ps1` with the three `gs://` paths so Firestore tokens stay in sync.

Update Firestore download URLs if the token changes (Console → file → copy new URL), or keep the same path so the proxy keeps working.

## CapCut export settings

When exporting from CapCut for WWJD-DI web: choose **H.264**, **1080×1920** (portrait) or **1920×1080** (landscape), **MP4**.
