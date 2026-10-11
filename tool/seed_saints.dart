// ignore_for_file: avoid_print

//

// Feast saints: upload to Storage, then seed Firestore with Console download URLs.

//

// Holy Archangels Storage prefix:

//   Saints/2026-09-29-holy-archangels/{landscape,portrait}.mp4, poster.jpg

// Firestore: saints/holy-archangels (slug holy-archangels)

//

//   node functions/scripts/seed_holy_archangels.js

//   (requires ARCHANGELS_VIDEO_LANDSCAPE_URL, ARCHANGELS_POSTER_PORTRAIT_URL, etc.)

//

// Claver / Pio: node functions/scripts/seed_feast_saints.js



void main() {

  print('Upload: gcloud storage cp ... gs://wwjd-di-e36ce.firebasestorage.app/Saints/...');

  print('Archangels only: .\\scripts\\seed-holy-archangels.ps1');

  print('All feast saints: .\\scripts\\seed-feast-saints.ps1');

  print('Slugs: peter-claver, pio-pietrelcina, holy-archangels');

}


