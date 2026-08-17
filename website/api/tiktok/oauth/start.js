import crypto from "node:crypto";
import { buildAuthorizeUrl, json, redirect } from "../_lib/tiktok.js";

export default function handler(req, res) {
  try {
    if (req.method !== "GET") {
      return json(res, 405, { error: "method_not_allowed" });
    }
    const url = new URL(req.url, `https://${req.headers.host || "useprocess.xyz"}`);
    const add = url.searchParams.get("add") === "1";
    const state = `studio_${add ? "add_" : ""}${crypto.randomBytes(16).toString("hex")}`;
    const secure = process.env.VERCEL || process.env.NODE_ENV === "production";
    const parts = [
      `process_studio_oauth_state=${encodeURIComponent(state)}`,
      "Path=/",
      "HttpOnly",
      "SameSite=Lax",
      "Max-Age=600",
    ];
    if (secure) parts.push("Secure");
    res.setHeader("Set-Cookie", parts.join("; "));
    return redirect(res, buildAuthorizeUrl(state));
  } catch (e) {
    return json(res, 500, { error: String(e.message || e) });
  }
}
