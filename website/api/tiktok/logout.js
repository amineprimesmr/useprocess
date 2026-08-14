import { clearSessionCookie } from "./_lib/session.js";
import { json } from "./_lib/tiktok.js";

export default function handler(req, res) {
  if (req.method !== "POST" && req.method !== "GET") {
    return json(res, 405, { error: "method_not_allowed" });
  }
  clearSessionCookie(res);
  return json(res, 200, { ok: true });
}
