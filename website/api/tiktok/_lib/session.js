import crypto from "node:crypto";

const COOKIE = "process_studio_session";
const MAX_AGE_SEC = 60 * 60 * 24 * 30; // 30 days
/** Soft cap — browsers ~4KB/cookie; keep room for signature. */
const MAX_COOKIE_CHARS = 3500;

function secret() {
  const s = process.env.STUDIO_SESSION_SECRET || process.env.TIKTOK_CLIENT_SECRET;
  if (!s) throw new Error("Missing STUDIO_SESSION_SECRET");
  return s;
}

function b64url(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function fromB64url(str) {
  const pad = str.length % 4 === 0 ? "" : "=".repeat(4 - (str.length % 4));
  return Buffer.from(str.replace(/-/g, "+").replace(/_/g, "/") + pad, "base64");
}

export function signPayload(payload) {
  const body = b64url(JSON.stringify(payload));
  const sig = crypto.createHmac("sha256", secret()).update(body).digest();
  return `${body}.${b64url(sig)}`;
}

export function verifyPayload(token) {
  if (!token || typeof token !== "string" || !token.includes(".")) return null;
  const [body, sig] = token.split(".");
  const expected = b64url(crypto.createHmac("sha256", secret()).update(body).digest());
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    return JSON.parse(fromB64url(body).toString("utf8"));
  } catch {
    return null;
  }
}

export function parseCookies(req) {
  const raw = req.headers.cookie || "";
  const out = {};
  for (const part of raw.split(";")) {
    const i = part.indexOf("=");
    if (i === -1) continue;
    const k = part.slice(0, i).trim();
    const v = part.slice(i + 1).trim();
    out[k] = decodeURIComponent(v);
  }
  return out;
}

/** Normalize legacy single-account sessions into multi-account shape. */
export function normalizeSession(raw) {
  if (!raw) return null;
  if (raw.accounts && typeof raw.accounts === "object") {
    const accounts = { ...raw.accounts };
    let active = raw.active_open_id || "";
    if (!active || !accounts[active]) {
      active = Object.keys(accounts)[0] || "";
    }
    return { active_open_id: active, accounts };
  }
  if (raw.access_token) {
    const open_id = raw.open_id || "default";
    return {
      active_open_id: open_id,
      accounts: {
        [open_id]: {
          access_token: raw.access_token,
          refresh_token: raw.refresh_token || "",
          expires_at: raw.expires_at || 0,
          open_id,
          scope: raw.scope || "",
          username: raw.username || "",
          display_name: raw.display_name || "",
          avatar_url: raw.avatar_url || "",
        },
      },
    };
  }
  return null;
}

export function getActiveAccount(session) {
  const s = normalizeSession(session);
  if (!s?.active_open_id) return null;
  return s.accounts[s.active_open_id] || null;
}

export function upsertAccount(session, account) {
  const s = normalizeSession(session) || { active_open_id: "", accounts: {} };
  const open_id = account.open_id || `tmp_${Date.now()}`;
  const prev = s.accounts[open_id] || {};
  s.accounts[open_id] = {
    ...prev,
    ...account,
    open_id,
  };
  s.active_open_id = open_id;
  return s;
}

export function switchAccount(session, openId) {
  const s = normalizeSession(session);
  if (!s?.accounts?.[openId]) throw new Error("account_not_found");
  return { ...s, active_open_id: openId };
}

export function removeAccount(session, openId) {
  const s = normalizeSession(session);
  if (!s) return null;
  const accounts = { ...s.accounts };
  delete accounts[openId];
  const ids = Object.keys(accounts);
  if (!ids.length) return null;
  const active = s.active_open_id === openId ? ids[0] : s.active_open_id;
  return { active_open_id: active, accounts };
}

export function listAccountsPublic(session) {
  const s = normalizeSession(session);
  if (!s) return [];
  return Object.values(s.accounts).map((a) => ({
    open_id: a.open_id,
    username: a.username || "",
    display_name: a.display_name || "",
    avatar_url: a.avatar_url || "",
    active: a.open_id === s.active_open_id,
    scope: a.scope || "",
  }));
}

export function readSession(req) {
  const cookies = parseCookies(req);
  return normalizeSession(verifyPayload(cookies[COOKIE]));
}

export function setSessionCookie(res, payload) {
  const normalized = normalizeSession(payload);
  if (!normalized) {
    clearSessionCookie(res);
    return;
  }
  const token = signPayload(normalized);
  if (token.length > MAX_COOKIE_CHARS) {
    throw new Error(
      "too_many_accounts_cookie_limit — disconnect one account or contact support for multi-account storage upgrade"
    );
  }
  const secure = process.env.VERCEL || process.env.NODE_ENV === "production";
  const parts = [
    `${COOKIE}=${encodeURIComponent(token)}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Lax",
    `Max-Age=${MAX_AGE_SEC}`,
  ];
  if (secure) parts.push("Secure");
  res.setHeader("Set-Cookie", parts.join("; "));
}

export function clearSessionCookie(res) {
  const secure = process.env.VERCEL || process.env.NODE_ENV === "production";
  const parts = [`${COOKIE}=`, "Path=/", "HttpOnly", "SameSite=Lax", "Max-Age=0"];
  if (secure) parts.push("Secure");
  res.setHeader("Set-Cookie", parts.join("; "));
}

export { COOKIE, MAX_AGE_SEC };
