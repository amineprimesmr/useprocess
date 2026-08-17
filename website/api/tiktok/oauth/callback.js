import { exchangeCode, fetchUserInfo, json, redirect } from "../_lib/tiktok.js";
import {
  COOKIE,
  parseCookies,
  readSession,
  setSessionCookie,
  signPayload,
  upsertAccount,
} from "../_lib/session.js";

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
    let profile = {};
    try {
      profile = await fetchUserInfo(tokens.access_token);
    } catch {
      profile = {};
    }

    const isAdd = String(state).includes("_add_");
    const existing = isAdd ? readSession(req) : null;
    const open_id = tokens.open_id || profile.open_id || `u_${Date.now()}`;
    const nextSession = upsertAccount(existing, {
      ...tokens,
      open_id,
      username: profile.username || "",
      display_name: profile.display_name || "",
      avatar_url: profile.avatar_url || profile.avatar_url_100 || "",
    });

    const secure = process.env.VERCEL || process.env.NODE_ENV === "production";
    try {
      setSessionCookie(res, nextSession);
    } catch (e) {
      // Cookie too large — fall back to this account only
      const solo = upsertAccount(null, {
        ...tokens,
        open_id,
        username: profile.username || "",
        display_name: profile.display_name || "",
        avatar_url: profile.avatar_url || profile.avatar_url_100 || "",
      });
      const token = signPayload(solo);
      const sessionParts = [
        `${COOKIE}=${encodeURIComponent(token)}`,
        "Path=/",
        "HttpOnly",
        "SameSite=Lax",
        `Max-Age=${60 * 60 * 24 * 30}`,
      ];
      if (secure) sessionParts.push("Secure");
      res.setHeader("Set-Cookie", [
        sessionParts.join("; "),
        `process_studio_oauth_state=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0${secure ? "; Secure" : ""}`,
      ]);
      return redirect(res, `/studio?connected=1&warn=${encodeURIComponent(String(e.message || e).slice(0, 120))}`);
    }

    const clearState = [
      "process_studio_oauth_state=",
      "Path=/",
      "HttpOnly",
      "SameSite=Lax",
      "Max-Age=0",
    ];
    if (secure) clearState.push("Secure");
    // setSessionCookie already set Set-Cookie — append clear state
    const existingCookie = res.getHeader("Set-Cookie");
    const list = Array.isArray(existingCookie)
      ? existingCookie
      : existingCookie
        ? [existingCookie]
        : [];
    list.push(clearState.join("; "));
    res.setHeader("Set-Cookie", list);

    return redirect(res, `/studio?connected=1${isAdd ? "&added=1" : ""}`);
  } catch (e) {
    return redirect(res, `/studio?error=${encodeURIComponent(String(e.message || e).slice(0, 180))}`);
  }
}
