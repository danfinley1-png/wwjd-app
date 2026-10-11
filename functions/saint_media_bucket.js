const { getStorage } = require("firebase-admin/storage");

/** Firebase Storage bucket where feast saint media lives (not legacy appspot). */
const SAINT_MEDIA_BUCKET = "wwjd-di-e36ce.firebasestorage.app";

function getSaintMediaBucket() {
  return getStorage().bucket(SAINT_MEDIA_BUCKET);
}

module.exports = { SAINT_MEDIA_BUCKET, getSaintMediaBucket };
