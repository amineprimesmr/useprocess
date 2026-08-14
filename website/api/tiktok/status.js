import { ensureSession } from "./_lib/auth.js";
import { fetchStatus, json } from "./_lib/tiktok.js";

export default async function handler(req, res) {
  try {
    if (req.method !== "GET") {
      return json(res, 405, { error: "method_not_allowed" });
    }
    const session = await ensureSession(req, res);
    if (!session) {
      return json(res, 401, { error: "not_authenticated" });
    }
    const url = new URL(req.url, `https://${req.headers.host || "useprocess.xyz"}`);
    const publishId = url.searchParams.get("publish_id");
    if (!publishId) {
      return json(res, 400, { error: "publish_id_required" });
    }
    const data = await fetchStatus(session.access_token, publishId);
    return json(res, 200, { ok: true, data });
  } catch (e) {
    return json(res, 400, { error: String(e.message || e) });
  }
}
