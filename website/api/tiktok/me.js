import { ensureSession, requireActiveAccount } from "./_lib/auth.js";
import { listAccountsPublic } from "./_lib/session.js";
import { creatorInfo, fetchUserInfo, json } from "./_lib/tiktok.js";

export default async function handler(req, res) {
  try {
    if (req.method !== "GET") {
      return json(res, 405, { error: "method_not_allowed" });
    }
    const session = await ensureSession(req, res);
    if (!session) {
      return json(res, 401, { error: "not_authenticated" });
    }
    const active = requireActiveAccount(session);
    if (!active) {
      return json(res, 401, { error: "not_authenticated" });
    }

    let creator = {};
    let user = {};
    try {
      creator = await creatorInfo(active.access_token);
    } catch (e) {
      creator = { _error: String(e.message || e) };
    }
    try {
      user = await fetchUserInfo(active.access_token);
    } catch (e) {
      user = {
        open_id: active.open_id,
        username: active.username,
        display_name: active.display_name,
        avatar_url: active.avatar_url,
        _error: String(e.message || e),
      };
    }

    return json(res, 200, {
      connected: true,
      open_id: active.open_id || user.open_id || null,
      scope: active.scope || null,
      sandbox: process.env.TIKTOK_SANDBOX === "1",
      creator,
      user,
      accounts: listAccountsPublic(session),
    });
  } catch (e) {
    const msg = String(e.message || e);
    if (/access_token|unauthorized|401/i.test(msg)) {
      return json(res, 401, { error: msg });
    }
    return json(res, 500, { error: msg });
  }
}
