import { ensureSession, requireActiveAccount } from "./_lib/auth.js";
import { clearSessionCookie, getActiveAccount, normalizeSession } from "./_lib/session.js";
import { json, revokeAccessToken } from "./_lib/tiktok.js";

export default async function handler(req, res) {
  if (req.method !== "POST" && req.method !== "GET") {
    return json(res, 405, { error: "method_not_allowed" });
  }
  try {
    const session = await ensureSession(req, res);
    const s = normalizeSession(session);
    if (s?.accounts) {
      for (const acc of Object.values(s.accounts)) {
        if (acc?.access_token) await revokeAccessToken(acc.access_token);
      }
    } else {
      const active = getActiveAccount(session) || requireActiveAccount(session);
      if (active?.access_token) await revokeAccessToken(active.access_token);
    }
  } catch {
    // still clear cookie
  }
  clearSessionCookie(res);
  return json(res, 200, { ok: true });
}
