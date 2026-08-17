import {
  getActiveAccount,
  normalizeSession,
  readSession,
  setSessionCookie,
  upsertAccount,
} from "./session.js";
import { refreshAccessToken } from "./tiktok.js";

/** Load multi-account session; refresh active token if near expiry. */
export async function ensureSession(req, res) {
  let session = readSession(req);
  if (!session) return null;

  const active = getActiveAccount(session);
  if (!active?.access_token) return null;

  const skew = 5 * 60 * 1000;
  if (active.expires_at && Date.now() > active.expires_at - skew && active.refresh_token) {
    try {
      const next = await refreshAccessToken(active.refresh_token);
      session = upsertAccount(session, {
        ...active,
        ...next,
        open_id: next.open_id || active.open_id,
      });
      setSessionCookie(res, session);
    } catch {
      // keep existing token; caller may get 401 from TikTok
    }
  }
  return normalizeSession(session);
}

export function requireActiveAccount(session) {
  const active = getActiveAccount(session);
  if (!active?.access_token) return null;
  return active;
}
