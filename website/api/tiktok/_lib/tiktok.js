const AUTH_URL = "https://www.tiktok.com/v2/auth/authorize/";
const TOKEN_URL = "https://open.tiktokapis.com/v2/oauth/token/";
const REVOKE_URL = "https://open.tiktokapis.com/v2/oauth/revoke/";
const CREATOR_INFO = "https://open.tiktokapis.com/v2/post/publish/creator_info/query/";
const CONTENT_INIT = "https://open.tiktokapis.com/v2/post/publish/content/init/";
const STATUS_FETCH = "https://open.tiktokapis.com/v2/post/publish/status/fetch/";
const USER_INFO = "https://open.tiktokapis.com/v2/user/info/";
const VIDEO_LIST = "https://open.tiktokapis.com/v2/video/list/";

/**
 * Scopes for Studio OAuth.
 * Sandbox client keys (sbaw…) often only have Login Kit + Content Posting scopes
 * that were enabled on the Sandbox product — requesting stats/video.list there
 * returns TikTok error "scope". Full audit scopes apply once production key is used.
 */
export const OAUTH_SCOPES_PRODUCTION = [
  "user.info.basic",
  "user.info.profile",
  "user.info.stats",
  "video.list",
  "video.upload",
  "video.publish",
].join(",");

/** Safe default for Sandbox — must match scopes already enabled on the Sandbox client. */
export const OAUTH_SCOPES_SANDBOX = [
  "user.info.basic",
  "video.upload",
  "video.publish",
].join(",");

export function isSandboxClientKey(clientKey = process.env.TIKTOK_CLIENT_KEY || "") {
  return process.env.TIKTOK_SANDBOX === "1" || String(clientKey).startsWith("sbaw");
}

export function oauthScopes() {
  if (process.env.TIKTOK_OAUTH_SCOPES) return process.env.TIKTOK_OAUTH_SCOPES;
  return isSandboxClientKey() ? OAUTH_SCOPES_SANDBOX : OAUTH_SCOPES_PRODUCTION;
}

/** @deprecated use oauthScopes() — kept for any imports expecting a string constant */
export const OAUTH_SCOPES = OAUTH_SCOPES_PRODUCTION;

export const USER_INFO_FIELDS = [
  "open_id",
  "union_id",
  "avatar_url",
  "avatar_url_100",
  "display_name",
  "bio_description",
  "profile_deep_link",
  "is_verified",
  "username",
  "follower_count",
  "following_count",
  "likes_count",
  "video_count",
].join(",");

export const VIDEO_LIST_FIELDS = [
  "id",
  "create_time",
  "cover_image_url",
  "share_url",
  "video_description",
  "duration",
  "title",
  "like_count",
  "comment_count",
  "share_count",
  "view_count",
].join(",");

export function envConfig() {
  const clientKey = process.env.TIKTOK_CLIENT_KEY;
  const clientSecret = process.env.TIKTOK_CLIENT_SECRET;
  const redirectUri =
    process.env.TIKTOK_REDIRECT_URI || "https://useprocess.xyz/tiktok/callback";
  if (!clientKey || !clientSecret) {
    throw new Error("Missing TIKTOK_CLIENT_KEY / TIKTOK_CLIENT_SECRET");
  }
  return { clientKey, clientSecret, redirectUri };
}

export function buildAuthorizeUrl(state) {
  const { clientKey, redirectUri } = envConfig();
  const u = new URL(AUTH_URL);
  u.searchParams.set("client_key", clientKey);
  u.searchParams.set("response_type", "code");
  u.searchParams.set("scope", oauthScopes());
  u.searchParams.set("redirect_uri", redirectUri);
  u.searchParams.set("state", state);
  return u.toString();
}

function normalizeTokenPayload(data) {
  const access_token = data.access_token || data.data?.access_token;
  const refresh_token = data.refresh_token || data.data?.refresh_token || "";
  const expires_in = data.expires_in || data.data?.expires_in || 86400;
  const open_id = data.open_id || data.data?.open_id || "";
  const scope = data.scope || data.data?.scope || oauthScopes();
  if (!access_token) throw new Error(`Token exchange failed: ${JSON.stringify(data)}`);
  return {
    access_token,
    refresh_token,
    open_id,
    scope,
    expires_at: Date.now() + Number(expires_in) * 1000,
  };
}

export async function exchangeCode(code) {
  const { clientKey, clientSecret, redirectUri } = envConfig();
  const body = new URLSearchParams({
    client_key: clientKey,
    client_secret: clientSecret,
    code,
    grant_type: "authorization_code",
    redirect_uri: redirectUri,
  });
  const r = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await r.json();
  if (data.error || data.message === "error") {
    throw new Error(JSON.stringify(data));
  }
  return normalizeTokenPayload(data);
}

export async function refreshAccessToken(refreshToken) {
  const { clientKey, clientSecret } = envConfig();
  const body = new URLSearchParams({
    client_key: clientKey,
    client_secret: clientSecret,
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  });
  const r = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await r.json();
  return normalizeTokenPayload(data);
}

export async function revokeAccessToken(accessToken) {
  const { clientKey, clientSecret } = envConfig();
  const body = new URLSearchParams({
    client_key: clientKey,
    client_secret: clientSecret,
    token: accessToken,
  });
  try {
    await fetch(REVOKE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });
  } catch {
    // best-effort revoke
  }
}

async function tiktokPost(url, accessToken, jsonBody = {}) {
  const r = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json; charset=UTF-8",
    },
    body: JSON.stringify(jsonBody),
  });
  return r.json();
}

function assertTikTokOk(data) {
  const err = data.error || {};
  if (err.code && err.code !== "ok") {
    throw new Error(err.message || JSON.stringify(data));
  }
  return data.data || {};
}

export async function creatorInfo(accessToken) {
  return assertTikTokOk(await tiktokPost(CREATOR_INFO, accessToken, {}));
}

export async function initPhotoPost(accessToken, payload) {
  return assertTikTokOk(await tiktokPost(CONTENT_INIT, accessToken, payload));
}

export async function fetchStatus(accessToken, publishId) {
  return assertTikTokOk(await tiktokPost(STATUS_FETCH, accessToken, { publish_id: publishId }));
}

export async function fetchUserInfo(accessToken, fields = USER_INFO_FIELDS) {
  const u = new URL(USER_INFO);
  u.searchParams.set("fields", fields);
  const r = await fetch(u.toString(), {
    method: "GET",
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const data = await r.json();
  const err = data.error || {};
  if (err.code && err.code !== "ok") {
    throw new Error(err.message || JSON.stringify(data));
  }
  return data.data?.user || data.data || {};
}

export async function listVideos(accessToken, { cursor, max_count = 20 } = {}) {
  const u = new URL(VIDEO_LIST);
  u.searchParams.set("fields", VIDEO_LIST_FIELDS);
  const body = { max_count: Math.min(20, Math.max(1, Number(max_count) || 20)) };
  if (cursor != null && cursor !== "") body.cursor = Number(cursor);
  const data = await tiktokPost(u.toString(), accessToken, body);
  return assertTikTokOk(data);
}

export function json(res, status, body) {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.end(JSON.stringify(body));
}

export function redirect(res, location) {
  res.statusCode = 302;
  res.setHeader("Location", location);
  res.end();
}
