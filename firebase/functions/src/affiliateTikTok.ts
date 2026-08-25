import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { affiliateHttpStatus, db, getAffiliateForUid } from "./affiliateShared";
import { setCors, verifyAppAttestation, verifyFirebaseUser } from "./referralShared";

const AUTH_URL = "https://www.tiktok.com/v2/auth/authorize/";
const TOKEN_URL = "https://open.tiktokapis.com/v2/oauth/token/";
const REVOKE_URL = "https://open.tiktokapis.com/v2/oauth/revoke/";
const USER_INFO = "https://open.tiktokapis.com/v2/user/info/";
const VIDEO_LIST = "https://open.tiktokapis.com/v2/video/list/";
const CONTENT_INIT = "https://open.tiktokapis.com/v2/post/publish/content/init/";

const SITE = "https://useprocess.xyz/affiliate";
const DEFAULT_REDIRECT =
  "https://us-central1-useprocess-d4385.cloudfunctions.net/affiliateTikTokOAuthCallback";

const USER_INFO_FIELDS = [
  "open_id",
  "union_id",
  "avatar_url",
  "avatar_url_100",
  "display_name",
  "username",
  "follower_count",
  "following_count",
  "likes_count",
  "video_count",
].join(",");

const VIDEO_LIST_FIELDS = [
  "id",
  "create_time",
  "cover_image_url",
  "share_url",
  "video_description",
  "title",
  "like_count",
  "comment_count",
  "share_count",
  "view_count",
].join(",");

export type PublicTikTokAccount = {
  id: string;
  platform: string;
  name: string;
  handle: string;
  avatar: string;
  connected: boolean;
  followers: number;
  likes: number;
  videoCount: number;
  views: number;
  comments: number;
  shares: number;
};

function tiktokEnv() {
  const clientKey = String(process.env.TIKTOK_CLIENT_KEY || "").trim();
  const clientSecret = String(process.env.TIKTOK_CLIENT_SECRET || "").trim();
  const redirectUri = String(process.env.TIKTOK_REDIRECT_URI || DEFAULT_REDIRECT).trim();
  return { clientKey, clientSecret, redirectUri, ready: Boolean(clientKey && clientSecret) };
}

export function tiktokApiReady() {
  return tiktokEnv().ready;
}

function oauthScopes() {
  if (process.env.TIKTOK_OAUTH_SCOPES) return process.env.TIKTOK_OAUTH_SCOPES;
  const sandbox = process.env.TIKTOK_SANDBOX === "1" || tiktokEnv().clientKey.startsWith("sbaw");
  return sandbox
    ? "user.info.basic,video.upload,video.publish"
    : "user.info.basic,user.info.profile,user.info.stats,video.list,video.upload,video.publish";
}

function accountsCol(affiliateId: string) {
  return db().collection("affiliates").doc(affiliateId).collection("tiktokAccounts");
}

function postsCol(affiliateId: string) {
  return db().collection("affiliates").doc(affiliateId).collection("studioPosts");
}

function keysCol(affiliateId: string) {
  return db().collection("affiliates").doc(affiliateId).collection("mcpKeys");
}

function publicAccount(
  id: string,
  data: FirebaseFirestore.DocumentData | undefined
): PublicTikTokAccount {
  const row = data || {};
  return {
    id,
    platform: String(row.platform || "tiktok"),
    name: String(row.name || "TikTok"),
    handle: String(row.handle || ""),
    avatar: String(row.avatar || ""),
    connected: Boolean(row.connected && row.accessToken),
    followers: Number(row.followers || 0),
    likes: Number(row.likes || 0),
    videoCount: Number(row.videoCount || 0),
    views: Number(row.views || 0),
    comments: Number(row.comments || 0),
    shares: Number(row.shares || 0),
  };
}

export async function listPublicTikTokAccounts(affiliateId: string): Promise<PublicTikTokAccount[]> {
  const snap = await accountsCol(affiliateId).limit(40).get();
  return snap.docs.map((doc) => publicAccount(doc.id, doc.data()));
}

export function tiktokTotals(accounts: PublicTikTokAccount[]) {
  return accounts.reduce(
    (sum, row) => ({
      accounts: sum.accounts + 1,
      connected: sum.connected + (row.connected ? 1 : 0),
      followers: sum.followers + row.followers,
      likes: sum.likes + row.likes,
      videoCount: sum.videoCount + row.videoCount,
      views: sum.views + row.views,
      comments: sum.comments + row.comments,
      shares: sum.shares + row.shares,
    }),
    { accounts: 0, connected: 0, followers: 0, likes: 0, videoCount: 0, views: 0, comments: 0, shares: 0 }
  );
}

function buildAuthorizeUrl(state: string) {
  const { clientKey, redirectUri } = tiktokEnv();
  const url = new URL(AUTH_URL);
  url.searchParams.set("client_key", clientKey);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", oauthScopes());
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("state", state);
  return url.toString();
}

function normalizeToken(data: Record<string, any>) {
  const access_token = data.access_token || data.data?.access_token;
  if (!access_token) throw new Error(`Token exchange failed: ${JSON.stringify(data)}`);
  return {
    access_token,
    refresh_token: data.refresh_token || data.data?.refresh_token || "",
    open_id: data.open_id || data.data?.open_id || "",
    expires_at: Date.now() + Number(data.expires_in || data.data?.expires_in || 86400) * 1000,
  };
}

async function exchangeCode(code: string) {
  const { clientKey, clientSecret, redirectUri } = tiktokEnv();
  const body = new URLSearchParams({
    client_key: clientKey,
    client_secret: clientSecret,
    code,
    grant_type: "authorization_code",
    redirect_uri: redirectUri,
  });
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await res.json();
  if (data.error || data.message === "error") throw new Error(JSON.stringify(data));
  return normalizeToken(data);
}

async function fetchUserInfo(accessToken: string) {
  const url = new URL(USER_INFO);
  url.searchParams.set("fields", USER_INFO_FIELDS);
  const res = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const data = await res.json();
  const err = data.error || {};
  if (err.code && err.code !== "ok") throw new Error(err.message || JSON.stringify(data));
  return data.data?.user || data.data || {};
}

async function listVideos(accessToken: string) {
  const url = new URL(VIDEO_LIST);
  url.searchParams.set("fields", VIDEO_LIST_FIELDS);
  const res = await fetch(url.toString(), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json; charset=UTF-8",
    },
    body: JSON.stringify({ max_count: 20 }),
  });
  const data = await res.json();
  const err = data.error || {};
  if (err.code && err.code !== "ok") throw new Error(err.message || JSON.stringify(data));
  return data.data || {};
}

async function revokeAccessToken(accessToken: string) {
  const { clientKey, clientSecret } = tiktokEnv();
  if (!clientKey || !accessToken) return;
  try {
    await fetch(REVOKE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_key: clientKey,
        client_secret: clientSecret,
        token: accessToken,
      }),
    });
  } catch {
    /* best-effort */
  }
}

export function hashMcpToken(raw: string) {
  return crypto.createHash("sha256").update(raw).digest("hex");
}

function publicPost(id: string, data: FirebaseFirestore.DocumentData) {
  return {
    id,
    channelIds: Array.isArray(data.channelIds) ? data.channelIds : [],
    date: String(data.date || ""),
    time: String(data.time || "18:00"),
    status: String(data.status || "draft"),
    caption: String(data.caption || data.body || ""),
    image: String(data.image || ""),
    views: Number(data.views || 0),
    likes: Number(data.likes || 0),
    comments: Number(data.comments || 0),
    shares: Number(data.shares || 0),
    privacy: String(data.privacy || "PUBLIC_TO_EVERYONE"),
    inCalendar: data.inCalendar !== false,
  };
}

export async function loadStudio(affiliateId: string) {
  const [accounts, postsSnap, keysSnap] = await Promise.all([
    listPublicTikTokAccounts(affiliateId),
    postsCol(affiliateId).limit(80).get(),
    keysCol(affiliateId).limit(20).get(),
  ]);
  const posts = postsSnap.docs
    .map((doc) => publicPost(doc.id, doc.data()))
    .sort((a, b) => `${b.date}${b.time}`.localeCompare(`${a.date}${a.time}`));
  const keys = keysSnap.docs.map((doc) => ({
    id: doc.id,
    name: String(doc.data()?.name || "Agent"),
    prefix: String(doc.data()?.prefix || ""),
    createdAt: doc.data()?.createdAt?.toMillis?.() || null,
  }));
  return {
    apiReady: tiktokApiReady(),
    accounts,
    totals: tiktokTotals(accounts),
    posts,
    keys,
  };
}

async function refreshAccountStats(affiliateId: string, accountId: string) {
  const ref = accountsCol(affiliateId).doc(accountId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error("AFFILIATE_NOT_FOUND");
  const token = String(snap.data()?.accessToken || "");
  if (!token) return publicAccount(accountId, snap.data());
  const profile = await fetchUserInfo(token);
  let views = 0;
  let comments = 0;
  let shares = 0;
  let likes = Number(profile.likes_count || snap.data()?.likes || 0);
  try {
    const listed = await listVideos(token);
    const videos = Array.isArray(listed.videos) ? listed.videos : listed.list || [];
    for (const video of videos) {
      views += Number(video.view_count || 0);
      likes += Number(video.like_count || 0);
      comments += Number(video.comment_count || 0);
      shares += Number(video.share_count || 0);
    }
  } catch {
    /* stats scopes may be missing in sandbox */
  }
  const patch = {
    name: profile.display_name || profile.username || snap.data()?.name,
    handle: profile.username || snap.data()?.handle,
    avatar: profile.avatar_url || profile.avatar_url_100 || snap.data()?.avatar || "",
    followers: Number(profile.follower_count || 0),
    likes: Number(profile.likes_count || likes || 0),
    videoCount: Number(profile.video_count || 0),
    views,
    comments,
    shares,
    connected: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await ref.set(patch, { merge: true });
  return publicAccount(accountId, { ...snap.data(), ...patch });
}

function redirectStudio(query: string) {
  return `${SITE}#/automatisation?${query}`;
}

export const affiliateTikTokOAuthCallback = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    const err = String(req.query?.error || "");
    const code = String(req.query?.code || "");
    const state = String(req.query?.state || "");
    if (err) {
      res.redirect(redirectStudio(`tab=connexions&error=${encodeURIComponent(err)}`));
      return;
    }
    if (!code || !state) {
      res.redirect(redirectStudio("tab=connexions&error=missing_code"));
      return;
    }
    try {
      const stateSnap = await db().collection("affiliateOAuthStates").doc(state).get();
      if (!stateSnap.exists) {
        res.redirect(redirectStudio("tab=connexions&error=state_mismatch"));
        return;
      }
      const affiliateId = String(stateSnap.data()?.affiliateId || "");
      const tokens = await exchangeCode(code);
      let profile: Record<string, any> = {};
      try {
        profile = await fetchUserInfo(tokens.access_token);
      } catch {
        profile = {};
      }
      const openId = tokens.open_id || profile.open_id || crypto.randomUUID();
      const existing = await accountsCol(affiliateId).where("openId", "==", openId).limit(1).get();
      const accountId = existing.docs[0]?.id || crypto.randomUUID();
      await accountsCol(affiliateId)
        .doc(accountId)
        .set(
          {
            platform: "tiktok",
            name: profile.display_name || profile.username || "TikTok",
            handle: profile.username || "tiktok",
            avatar: profile.avatar_url || profile.avatar_url_100 || "",
            connected: true,
            accessToken: tokens.access_token,
            refreshToken: tokens.refresh_token,
            openId,
            expiresAt: tokens.expires_at,
            followers: Number(profile.follower_count || 0),
            likes: Number(profile.likes_count || 0),
            videoCount: Number(profile.video_count || 0),
            views: 0,
            comments: 0,
            shares: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: existing.docs[0]?.data()?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      await stateSnap.ref.delete();
      try {
        await refreshAccountStats(affiliateId, accountId);
      } catch {
        /* profile is enough */
      }
      res.redirect(redirectStudio("tab=connexions&connected=tiktok"));
    } catch (error: any) {
      const raw = String(error?.message || "oauth");
      let codeName = "oauth";
      if (raw.includes("invalid_client")) codeName = "invalid_client";
      else if (raw.includes("invalid_grant") || raw.includes("invalid_code")) codeName = "invalid_grant";
      res.redirect(redirectStudio(`tab=connexions&error=${encodeURIComponent(codeName)}`));
    }
  }
);

export const affiliateTikTokStudio = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const uid = await verifyFirebaseUser(req);
      await verifyAppAttestation(req);
      const affiliate = await getAffiliateForUid(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }
      const action = String(req.body?.action || "list");
      const affiliateId = affiliate.affiliateId;

      if (action === "list") {
        res.status(200).json({ ok: true, ...(await loadStudio(affiliateId)) });
        return;
      }

      if (action === "connectStart") {
        if (!tiktokApiReady()) {
          res.status(200).json({
            ok: true,
            pendingApi: true,
            apiReady: false,
          });
          return;
        }
        const state = crypto.randomUUID();
        await db()
          .collection("affiliateOAuthStates")
          .doc(state)
          .set({
            affiliateId,
            uid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: Date.now() + 10 * 60 * 1000,
          });
        res.status(200).json({ ok: true, apiReady: true, url: buildAuthorizeUrl(state) });
        return;
      }

      if (action === "disconnect") {
        const accountId = String(req.body?.accountId || "");
        if (!accountId) throw new Error("INVALID_TEXT");
        const ref = accountsCol(affiliateId).doc(accountId);
        const snap = await ref.get();
        if (snap.exists) {
          await revokeAccessToken(String(snap.data()?.accessToken || ""));
          await ref.set(
            {
              connected: false,
              accessToken: admin.firestore.FieldValue.delete(),
              refreshToken: admin.firestore.FieldValue.delete(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
        res.status(200).json({ ok: true, ...(await loadStudio(affiliateId)) });
        return;
      }

      if (action === "refreshStats") {
        const accounts = await listPublicTikTokAccounts(affiliateId);
        for (const row of accounts.filter((item) => item.connected)) {
          try {
            await refreshAccountStats(affiliateId, row.id);
          } catch {
            /* keep stored stats */
          }
        }
        res.status(200).json({ ok: true, ...(await loadStudio(affiliateId)) });
        return;
      }

      if (action === "savePost") {
        const id = String(req.body?.id || crypto.randomUUID());
        const caption = String(req.body?.caption || req.body?.body || "").trim();
        if (!caption) throw new Error("INVALID_TEXT");
        await postsCol(affiliateId)
          .doc(id)
          .set(
            {
              caption,
              body: caption,
              date: String(req.body?.date || new Date().toISOString().slice(0, 10)),
              time: String(req.body?.time || "18:00"),
              status: String(req.body?.status || "draft"),
              channelIds: Array.isArray(req.body?.channelIds) ? req.body.channelIds : [],
              image: String(req.body?.image || ""),
              privacy: String(req.body?.privacy || "PUBLIC_TO_EVERYONE"),
              inCalendar: req.body?.inCalendar !== false,
              views: Number(req.body?.views || 0),
              likes: Number(req.body?.likes || 0),
              comments: Number(req.body?.comments || 0),
              shares: Number(req.body?.shares || 0),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        res.status(200).json({ ok: true, id, ...(await loadStudio(affiliateId)) });
        return;
      }

      if (action === "deletePost") {
        const id = String(req.body?.id || "");
        if (!id) throw new Error("INVALID_TEXT");
        await postsCol(affiliateId).doc(id).delete();
        res.status(200).json({ ok: true, ...(await loadStudio(affiliateId)) });
        return;
      }

      if (action === "publishNow") {
        const id = String(req.body?.id || "");
        if (!id) throw new Error("INVALID_TEXT");
        const postSnap = await postsCol(affiliateId).doc(id).get();
        if (!postSnap.exists) throw new Error("AFFILIATE_NOT_FOUND");
        const post = postSnap.data() || {};
        const channelId = String((post.channelIds || [])[0] || req.body?.accountId || "");
        const account = channelId ? await accountsCol(affiliateId).doc(channelId).get() : null;
        const token = String(account?.data()?.accessToken || "");
        if (!tiktokApiReady() || !token) {
          await postSnap.ref.set(
            { status: "scheduled", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
            { merge: true }
          );
          res.status(200).json({
            ok: true,
            pendingApi: !token || !tiktokApiReady(),
            ...(await loadStudio(affiliateId)),
          });
          return;
        }
        const init = await fetch(CONTENT_INIT, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json; charset=UTF-8",
          },
          body: JSON.stringify({
            post_info: {
              title: String(post.caption || "").slice(0, 90),
              privacy_level: String(post.privacy || "PUBLIC_TO_EVERYONE"),
              disable_comment: Boolean(post.commentsOff),
            },
            source_info: {
              source: "PULL_FROM_URL",
              photo_cover_index: 0,
              photo_images: Array.isArray(post.photo_images) ? post.photo_images : [],
            },
            post_mode: "DIRECT_POST",
            media_type: "PHOTO",
          }),
        });
        const initData = await init.json();
        await postSnap.ref.set(
          {
            status: "published",
            publishResult: initData,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        res.status(200).json({ ok: true, publish: initData, ...(await loadStudio(affiliateId)) });
        return;
      }

      if (action === "createKey") {
        const raw = `ss_live_${crypto.randomBytes(24).toString("hex")}`;
        const id = hashMcpToken(raw);
        const prefix = raw.slice(0, 14);
        await keysCol(affiliateId)
          .doc(id)
          .set({
            prefix,
            name: String(req.body?.name || "Agent").slice(0, 40),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastUsedAt: null,
          });
        await db().collection("mcpKeyIndex").doc(id).set({
          affiliateId,
          prefix,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(200).json({
          ok: true,
          token: raw,
          ...(await loadStudio(affiliateId)),
        });
        return;
      }

      if (action === "revokeKey") {
        const id = String(req.body?.id || "");
        if (!id) throw new Error("INVALID_TEXT");
        await keysCol(affiliateId).doc(id).delete();
        await db().collection("mcpKeyIndex").doc(id).delete();
        res.status(200).json({ ok: true, ...(await loadStudio(affiliateId)) });
        return;
      }

      res.status(400).json({ error: "INVALID_TEXT" });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateTikTokStudio]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);
