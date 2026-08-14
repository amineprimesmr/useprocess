import { ensureSession } from "./_lib/auth.js";
import { creatorInfo, json } from "./_lib/tiktok.js";

export default async function handler(req, res) {
  try {
    if (req.method !== "GET") {
      return json(res, 405, { error: "method_not_allowed" });
    }
    const session = await ensureSession(req, res);
    if (!session) {
      return json(res, 401, { error: "not_authenticated" });
    }
    const info = await creatorInfo(session.access_token);
    return json(res, 200, {
      connected: true,
      open_id: session.open_id || null,
      creator: info,
    });
  } catch (e) {
    const msg = String(e.message || e);
    if (/access_token|unauthorized|401/i.test(msg)) {
      return json(res, 401, { error: msg });
    }
    return json(res, 500, { error: msg });
  }
}
