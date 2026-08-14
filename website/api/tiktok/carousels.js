import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { json } from "./_lib/tiktok.js";

export default async function handler(req, res) {
  try {
    if (req.method !== "GET") {
      return json(res, 405, { error: "method_not_allowed" });
    }
    // On Vercel, public assets live next to the function or at project root
    const candidates = [
      join(process.cwd(), "public/tiktok-media/carousels/manifest.json"),
      join(process.cwd(), "tiktok-media/carousels/manifest.json"),
      join(process.cwd(), "../public/tiktok-media/carousels/manifest.json"),
    ];
    let raw = null;
    for (const p of candidates) {
      try {
        raw = await readFile(p, "utf8");
        break;
      } catch {
        /* try next */
      }
    }
    if (!raw) {
      // Fallback: fetch from same origin CDN path
      const host = req.headers.host || "useprocess.xyz";
      const proto = process.env.VERCEL ? "https" : "https";
      const r = await fetch(`${proto}://${host}/tiktok-media/carousels/manifest.json`);
      if (!r.ok) {
        return json(res, 404, { error: "manifest_not_found" });
      }
      raw = await r.text();
    }
    const data = JSON.parse(raw);
    return json(res, 200, data);
  } catch (e) {
    return json(res, 500, { error: String(e.message || e) });
  }
}
