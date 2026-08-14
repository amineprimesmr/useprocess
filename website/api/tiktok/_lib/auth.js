import { readSession, setSessionCookie } from "./session.js";
import { refreshAccessToken } from "./tiktok.js";

/** Load session; refresh token if near expiry. Returns { session, refreshed }. */
export async function ensureSession(req, res) {
  let session = readSession(req);
  if (!session?.access_token) return null;

  const skew = 5 * 60 * 1000;
  if (session.expires_at && Date.now() > session.expires_at - skew && session.refresh_token) {
    try {
      const next = await refreshAccessToken(session.refresh_token);
      session = {
        ...session,
        ...next,
        open_id: next.open_id || session.open_id,
      };
      setSessionCookie(res, session);
    } catch {
      // keep existing token; caller may get 401 from TikTok
    }
  }
  return session;
}
