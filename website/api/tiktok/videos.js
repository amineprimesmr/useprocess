import { ensureSession, requireActiveAccount } from "./_lib/auth.js";
import { json, listVideos } from "./_lib/tiktok.js";

export default async function handler(req, res) {
  try {
    if (req.method !== "GET") {
      return json(res, 405, { error: "method_not_allowed" });
    }
    const session = await ensureSession(req, res);
    const active = requireActiveAccount(session);
    if (!active) {
      return json(res, 401, { error: "not_authenticated" });
    }
    const url = new URL(req.url, `https://${req.headers.host || "useprocess.xyz"}`);
    const cursor = url.searchParams.get("cursor") || undefined;
    const max_count = Number(url.searchParams.get("max_count") || 20);
    const data = await listVideos(active.access_token, { cursor, max_count });
    const videos = data.videos || [];
    const totals = videos.reduce(
      (acc, v) => {
        acc.views += Number(v.view_count || 0);
        acc.likes += Number(v.like_count || 0);
        acc.comments += Number(v.comment_count || 0);
        acc.shares += Number(v.share_count || 0);
        return acc;
      },
      { views: 0, likes: 0, comments: 0, shares: 0 }
    );
    return json(res, 200, {
      ok: true,
      videos,
      cursor: data.cursor ?? null,
      has_more: Boolean(data.has_more),
      page_totals: totals,
    });
  } catch (e) {
    const msg = String(e.message || e);
    if (/scope|authorized|permission/i.test(msg)) {
      return json(res, 403, { error: msg, hint: "reconnect_with_video.list" });
    }
    return json(res, 400, { error: msg });
  }
}
