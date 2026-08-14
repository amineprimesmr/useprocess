import { exchangeCode, json, redirect } from "../_lib/tiktok.js";
import { parseCookies, signPayload, COOKIE } from "../_lib/session.js";

export default async function handler(req, res) {
  try {
    if (req.method !== "GET") {
      return json(res, 405, { error: "method_not_allowed" });
    }
    const url = new URL(req.url, `https://${req.headers.host || "useprocess.xyz"}`);
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state") || "";
    const err = url.searchParams.get("error");
    if (err) {
      return redirect(res, `/studio?error=${encodeURIComponent(err)}`);
    }
    if (!code) {
      return redirect(res, "/studio?error=missing_code");
    }
    const cookies = parseCookies(req);
    const expected = cookies.process_studio_oauth_state || "";
    if (expected && state && expected !== state) {
      return redirect(res, "/studio?error=state_mismatch");
    }
    if (!String(state).startsWith("studio_")) {
      return redirect(res, "/studio?error=invalid_state");
    }

    const tokens = await exchangeCode(code);
    const secure = process.env.VERCEL || process.env.NODE_ENV === "production";
    const sessionToken = signPayload(tokens);
    const sessionParts = [
      `${COOKIE}=${encodeURIComponent(sessionToken)}`,
      "Path=/",
      "HttpOnly",
      "SameSite=Lax",
      `Max-Age=${60 * 60 * 24 * 30}`,
    ];
    if (secure) sessionParts.push("Secure");

    const clearState = [
      "process_studio_oauth_state=",
      "Path=/",
      "HttpOnly",
      "SameSite=Lax",
      "Max-Age=0",
    ];
    if (secure) clearState.push("Secure");

    res.setHeader("Set-Cookie", [sessionParts.join("; "), clearState.join("; ")]);
    return redirect(res, "/studio?connected=1");
  } catch (e) {
    return redirect(res, `/studio?error=${encodeURIComponent(String(e.message || e).slice(0, 180))}`);
  }
}
