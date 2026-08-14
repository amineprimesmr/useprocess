import crypto from "node:crypto";

const COOKIE = "process_studio_session";
const MAX_AGE_SEC = 60 * 60 * 24 * 30; // 30 days

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

export function readSession(req) {
  const cookies = parseCookies(req);
  return verifyPayload(cookies[COOKIE]);
}

export function setSessionCookie(res, payload) {
  const token = signPayload(payload);
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

export { COOKIE };
