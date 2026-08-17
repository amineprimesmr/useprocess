import { ensureSession, requireActiveAccount } from "./_lib/auth.js";
import {
  clearSessionCookie,
  listAccountsPublic,
  removeAccount,
  setSessionCookie,
  switchAccount,
} from "./_lib/session.js";
import { json, revokeAccessToken } from "./_lib/tiktok.js";

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      try {
        const raw = Buffer.concat(chunks).toString("utf8") || "{}";
        resolve(JSON.parse(raw));
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

export default async function handler(req, res) {
  try {
    if (req.method === "GET") {
      const session = await ensureSession(req, res);
      if (!session) return json(res, 401, { error: "not_authenticated" });
      return json(res, 200, { accounts: listAccountsPublic(session) });
    }

    if (req.method !== "POST") {
      return json(res, 405, { error: "method_not_allowed" });
    }

    const session = await ensureSession(req, res);
    if (!session) return json(res, 401, { error: "not_authenticated" });

    const body = await readBody(req);
    const action = String(body.action || "");
    const openId = String(body.open_id || "");

    if (action === "switch") {
      if (!openId) return json(res, 400, { error: "open_id_required" });
      const next = switchAccount(session, openId);
      setSessionCookie(res, next);
      return json(res, 200, { ok: true, accounts: listAccountsPublic(next) });
    }

    if (action === "remove") {
      if (!openId) return json(res, 400, { error: "open_id_required" });
      const target = session.accounts?.[openId];
      if (target?.access_token) {
        await revokeAccessToken(target.access_token);
      }
      const next = removeAccount(session, openId);
      if (!next) {
        clearSessionCookie(res);
        return json(res, 200, { ok: true, accounts: [] });
      }
      setSessionCookie(res, next);
      return json(res, 200, { ok: true, accounts: listAccountsPublic(next) });
    }

    return json(res, 400, { error: "unknown_action" });
  } catch (e) {
    return json(res, 400, { error: String(e.message || e) });
  }
}
