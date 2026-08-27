const { onRequest } = require("firebase-functions/v2/https");

const MASSTIMES_API = "https://apiv4.updateparishdata.org/Churchs/";
const NOMINATIM_SEARCH = "https://nominatim.openstreetmap.org/search";
const NOMINATIM_REVERSE = "https://nominatim.openstreetmap.org/reverse";
const USER_AGENT =
  "WWJD-DI/1.0 (https://wwjd-di-e36ce.web.app; local worship times)";

function parseCoord(value) {
  const n = typeof value === "number" ? value : parseFloat(value);
  return Number.isFinite(n) ? n : null;
}

async function geocodeAddress(address) {
  const url = new URL(NOMINATIM_SEARCH);
  url.searchParams.set("q", address);
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "1");
  const response = await fetch(url, {
    headers: { Accept: "application/json", "User-Agent": USER_AGENT },
  });
  if (!response.ok) return null;
  const json = await response.json();
  if (!Array.isArray(json) || json.length === 0) return null;
  const lat = parseCoord(json[0].lat);
  const lng = parseCoord(json[0].lon);
  if (lat == null || lng == null) return null;
  return {
    latitude: lat,
    longitude: lng,
    label: json[0].display_name || address,
  };
}

async function reverseGeocode(lat, lng) {
  const url = new URL(NOMINATIM_REVERSE);
  url.searchParams.set("lat", String(lat));
  url.searchParams.set("lon", String(lng));
  url.searchParams.set("format", "json");
  const response = await fetch(url, {
    headers: { Accept: "application/json", "User-Agent": USER_AGENT },
  });
  if (!response.ok) return "";
  const json = await response.json();
  return typeof json.display_name === "string" ? json.display_name : "";
}

/**
 * Proxies the official MassTimes Trust parish API (no HTML scraping).
 * Hosting rewrite: /api/nearby-parishes -> nearbyParishes
 */
function registerNearbyParishes(exports) {
  exports.nearbyParishes = onRequest(
    {
      cors: true,
      timeoutSeconds: 30,
      invoker: "public",
    },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "GET" && req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      const src = req.method === "GET" ? req.query : req.body || {};
      let lat = parseCoord(src.lat);
      let lng = parseCoord(src.lng ?? src.long);
      let label = typeof src.address === "string" ? src.address.trim() : "";
      const page = Math.max(1, parseInt(src.page || src.pg || "1", 10) || 1);

      try {
        if ((lat == null || lng == null) && label) {
          const origin = await geocodeAddress(label);
          if (!origin) {
            res.status(404).json({ error: "Address not found" });
            return;
          }
          lat = origin.latitude;
          lng = origin.longitude;
          label = origin.label || label;
        }

        if (lat == null || lng == null) {
          res.status(400).json({
            error: "Provide a street address or latitude and longitude.",
          });
          return;
        }

        if (!label) {
          label = await reverseGeocode(lat, lng);
        }

        const url = `${MASSTIMES_API}?lat=${encodeURIComponent(lat)}&long=${encodeURIComponent(lng)}&pg=${page}`;
        const upstream = await fetch(url, {
          headers: { Accept: "application/json", "User-Agent": USER_AGENT },
        });
        const text = await upstream.text();
        let churches = [];
        try {
          const parsed = JSON.parse(text);
          if (Array.isArray(parsed)) churches = parsed;
        } catch (err) {
          console.error("nearbyParishes JSON parse error:", err);
        }

        if (!upstream.ok) {
          res.status(502).json({
            error: "MassTimes parish data is temporarily unavailable.",
          });
          return;
        }

        res.status(200).json({
          origin: { latitude: lat, longitude: lng, label },
          churches,
        });
      } catch (err) {
        console.error("nearbyParishes error:", err);
        res.status(502).json({ error: "Nearby parish lookup failed" });
      }
    }
  );
}

module.exports = { registerNearbyParishes };
