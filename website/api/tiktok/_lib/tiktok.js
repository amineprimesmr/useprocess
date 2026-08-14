const AUTH_URL = "https://www.tiktok.com/v2/auth/authorize/";
const TOKEN_URL = "https://open.tiktokapis.com/v2/oauth/token/";
const CREATOR_INFO = "https://open.tiktokapis.com/v2/post/publish/creator_info/query/";
const CONTENT_INIT = "https://open.tiktokapis.com/v2/post/publish/content/init/";
const STATUS_FETCH = "https://open.tiktokapis.com/v2/post/publish/status/fetch/";

export const OAUTH_SCOPES = "user.info.basic,video.upload,video.publish";

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
  u.searchParams.set("scope", OAUTH_SCOPES);
  u.searchParams.set("redirect_uri", redirectUri);
  u.searchParams.set("state", state);
  return u.toString();
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
  // TikTok returns flat or nested depending on version
  const access_token = data.access_token || data.data?.access_token;
  const refresh_token = data.refresh_token || data.data?.refresh_token;
  const expires_in = data.expires_in || data.data?.expires_in || 86400;
  const open_id = data.open_id || data.data?.open_id || "";
  const scope = data.scope || data.data?.scope || OAUTH_SCOPES;
  if (!access_token) throw new Error(`Token exchange failed: ${JSON.stringify(data)}`);
  return {
    access_token,
    refresh_token: refresh_token || "",
    open_id,
    scope,
    expires_at: Date.now() + Number(expires_in) * 1000,
  };
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
  const access_token = data.access_token || data.data?.access_token;
  const refresh_token = data.refresh_token || data.data?.refresh_token || refreshToken;
  const expires_in = data.expires_in || data.data?.expires_in || 86400;
  const open_id = data.open_id || data.data?.open_id || "";
  const scope = data.scope || data.data?.scope || OAUTH_SCOPES;
  if (!access_token) throw new Error(`Refresh failed: ${JSON.stringify(data)}`);
  return {
    access_token,
    refresh_token,
    open_id,
    scope,
    expires_at: Date.now() + Number(expires_in) * 1000,
  };
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

export async function creatorInfo(accessToken) {
  const data = await tiktokPost(CREATOR_INFO, accessToken, {});
  const err = data.error || {};
  if (err.code && err.code !== "ok") {
    throw new Error(err.message || JSON.stringify(data));
  }
  return data.data || {};
}

export async function initPhotoPost(accessToken, payload) {
  const data = await tiktokPost(CONTENT_INIT, accessToken, payload);
  const err = data.error || {};
  if (err.code && err.code !== "ok") {
    throw new Error(err.message || JSON.stringify(data));
  }
  return data.data || {};
}

export async function fetchStatus(accessToken, publishId) {
  const data = await tiktokPost(STATUS_FETCH, accessToken, { publish_id: publishId });
  const err = data.error || {};
  if (err.code && err.code !== "ok") {
    throw new Error(err.message || JSON.stringify(data));
  }
  return data.data || {};
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
