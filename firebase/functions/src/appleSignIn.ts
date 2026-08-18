import * as admin from "firebase-admin";
import crypto from "node:crypto";

const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";
const APPLE_AUDIENCE = "https://appleid.apple.com";
const APPLE_SIGNIN_DOC = "appleSignIn";

export interface AppleSignInConfig {
  teamId: string;
  keyId: string;
  clientId: string;
  privateKeyPem: string;
}

export interface AppleSignInSecrets {
  teamId: string;
  keyId: string;
  privateKey: string;
  clientId?: string;
}

function base64UrlEncode(input: Buffer | string): string {
  const buffer = typeof input === "string" ? Buffer.from(input, "utf8") : input;
  return buffer
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

export function createAppleClientSecret(config: AppleSignInConfig): string {
  const header = { alg: "ES256", kid: config.keyId, typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: config.teamId,
    iat: now,
    exp: now + 60 * 60 * 24 * 180,
    aud: APPLE_AUDIENCE,
    sub: config.clientId,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const key = crypto.createPrivateKey(config.privateKeyPem);
  const signature = crypto.sign("sha256", Buffer.from(signingInput), {
    key,
    dsaEncoding: "ieee-p1363",
  });

  return `${signingInput}.${base64UrlEncode(signature)}`;
}

function normalizePrivateKey(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.includes("BEGIN PRIVATE KEY")) return trimmed;
  const body = trimmed.replace(/\s+/g, "");
  const lines = body.match(/.{1,64}/g) ?? [body];
  return ["-----BEGIN PRIVATE KEY-----", ...lines, "-----END PRIVATE KEY-----"].join(
    "\n"
  );
}

export function resolveAppleSignInConfig(
  secrets: AppleSignInSecrets
): AppleSignInConfig {
  const teamId = secrets.teamId.trim();
  const keyId = secrets.keyId.trim();
  const clientId = (secrets.clientId?.trim() || "com.useprocess").trim();
  const privateKeyPem = normalizePrivateKey(secrets.privateKey);

  if (!teamId || !keyId || !privateKeyPem) {
    throw new Error("APPLE_SIGNIN_CONFIG_INCOMPLETE");
  }

  return { teamId, keyId, clientId, privateKeyPem };
}

async function postAppleForm(
  url: string,
  params: Record<string, string>
): Promise<any> {
  const body = new URLSearchParams(params);
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`APPLE_HTTP_${response.status}:${text}`);
  }

  if (!text.trim()) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

export async function exchangeAuthorizationCode(
  authorizationCode: string,
  config: AppleSignInConfig
): Promise<{ refreshToken?: string; accessToken?: string; idToken?: string }> {
  const clientSecret = createAppleClientSecret(config);
  const payload = await postAppleForm(APPLE_TOKEN_URL, {
    client_id: config.clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: "authorization_code",
  });

  const refreshToken =
    typeof payload.refresh_token === "string" ? payload.refresh_token : undefined;
  const accessToken =
    typeof payload.access_token === "string" ? payload.access_token : undefined;
  const idToken = typeof payload.id_token === "string" ? payload.id_token : undefined;

  if (!refreshToken && !accessToken) {
    throw new Error("APPLE_TOKEN_EXCHANGE_FAILED");
  }

  return { refreshToken, accessToken, idToken };
}

export async function revokeAppleToken(
  token: string,
  tokenTypeHint: "refresh_token" | "access_token",
  config: AppleSignInConfig
): Promise<void> {
  const clientSecret = createAppleClientSecret(config);
  await postAppleForm(APPLE_REVOKE_URL, {
    client_id: config.clientId,
    client_secret: clientSecret,
    token,
    token_type_hint: tokenTypeHint,
  });
}

function appleSignInDocRef(uid: string) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("privateMeta")
    .doc(APPLE_SIGNIN_DOC);
}

export async function storeAppleRefreshToken(
  uid: string,
  refreshToken: string,
  appleUserId?: string
): Promise<void> {
  await appleSignInDocRef(uid).set(
    {
      refreshToken,
      appleUserId: appleUserId ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

export async function loadAppleRefreshToken(uid: string): Promise<string | undefined> {
  const snap = await appleSignInDocRef(uid).get();
  const token = snap.data()?.refreshToken;
  return typeof token === "string" && token.length > 0 ? token : undefined;
}

export async function clearAppleRefreshToken(uid: string): Promise<void> {
  try {
    await appleSignInDocRef(uid).delete();
  } catch {
    // Best effort — doc may already be gone via recursiveDelete.
  }
}

export async function revokeAppleSignInForUser(
  uid: string,
  config: AppleSignInConfig,
  authorizationCode?: string
): Promise<{ revoked: boolean; reason?: string }> {
  let refreshToken = await loadAppleRefreshToken(uid);

  if (!refreshToken && authorizationCode) {
    try {
      const exchanged = await exchangeAuthorizationCode(authorizationCode, config);
      if (exchanged.refreshToken) {
        refreshToken = exchanged.refreshToken;
      } else if (exchanged.accessToken) {
        await revokeAppleToken(exchanged.accessToken, "access_token", config);
        await clearAppleRefreshToken(uid);
        return { revoked: true, reason: "access_token" };
      }
    } catch (error: any) {
      console.warn("[appleSignIn] exchange during revoke failed", error?.message ?? error);
    }
  }

  if (!refreshToken) {
    return { revoked: false, reason: "NO_APPLE_REFRESH_TOKEN" };
  }

  try {
    await revokeAppleToken(refreshToken, "refresh_token", config);
    await clearAppleRefreshToken(uid);
    return { revoked: true, reason: "refresh_token" };
  } catch (error: any) {
    console.error("[appleSignIn] revoke failed", error?.message ?? error);
    return { revoked: false, reason: error?.message ?? "REVOKE_FAILED" };
  }
}

export async function registerAppleAuthorizationCode(
  uid: string,
  authorizationCode: string,
  config: AppleSignInConfig,
  appleUserId?: string
): Promise<void> {
  const exchanged = await exchangeAuthorizationCode(authorizationCode, config);
  if (!exchanged.refreshToken) {
    throw new Error("APPLE_REFRESH_TOKEN_MISSING");
  }
  await storeAppleRefreshToken(uid, exchanged.refreshToken, appleUserId);
}
