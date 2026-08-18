"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createAppleClientSecret = createAppleClientSecret;
exports.resolveAppleSignInConfig = resolveAppleSignInConfig;
exports.exchangeAuthorizationCode = exchangeAuthorizationCode;
exports.revokeAppleToken = revokeAppleToken;
exports.storeAppleRefreshToken = storeAppleRefreshToken;
exports.loadAppleRefreshToken = loadAppleRefreshToken;
exports.clearAppleRefreshToken = clearAppleRefreshToken;
exports.revokeAppleSignInForUser = revokeAppleSignInForUser;
exports.registerAppleAuthorizationCode = registerAppleAuthorizationCode;
const admin = __importStar(require("firebase-admin"));
const node_crypto_1 = __importDefault(require("node:crypto"));
const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";
const APPLE_AUDIENCE = "https://appleid.apple.com";
const APPLE_SIGNIN_DOC = "appleSignIn";
function base64UrlEncode(input) {
    const buffer = typeof input === "string" ? Buffer.from(input, "utf8") : input;
    return buffer
        .toString("base64")
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/g, "");
}
function createAppleClientSecret(config) {
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
    const key = node_crypto_1.default.createPrivateKey(config.privateKeyPem);
    const signature = node_crypto_1.default.sign("sha256", Buffer.from(signingInput), {
        key,
        dsaEncoding: "ieee-p1363",
    });
    return `${signingInput}.${base64UrlEncode(signature)}`;
}
function normalizePrivateKey(raw) {
    const trimmed = raw.trim();
    if (trimmed.includes("BEGIN PRIVATE KEY"))
        return trimmed;
    const body = trimmed.replace(/\s+/g, "");
    const lines = body.match(/.{1,64}/g) ?? [body];
    return ["-----BEGIN PRIVATE KEY-----", ...lines, "-----END PRIVATE KEY-----"].join("\n");
}
function resolveAppleSignInConfig(secrets) {
    const teamId = secrets.teamId.trim();
    const keyId = secrets.keyId.trim();
    const clientId = (secrets.clientId?.trim() || "com.useprocess").trim();
    const privateKeyPem = normalizePrivateKey(secrets.privateKey);
    if (!teamId || !keyId || !privateKeyPem) {
        throw new Error("APPLE_SIGNIN_CONFIG_INCOMPLETE");
    }
    return { teamId, keyId, clientId, privateKeyPem };
}
async function postAppleForm(url, params) {
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
    if (!text.trim())
        return {};
    try {
        return JSON.parse(text);
    }
    catch {
        return { raw: text };
    }
}
async function exchangeAuthorizationCode(authorizationCode, config) {
    const clientSecret = createAppleClientSecret(config);
    const payload = await postAppleForm(APPLE_TOKEN_URL, {
        client_id: config.clientId,
        client_secret: clientSecret,
        code: authorizationCode,
        grant_type: "authorization_code",
    });
    const refreshToken = typeof payload.refresh_token === "string" ? payload.refresh_token : undefined;
    const accessToken = typeof payload.access_token === "string" ? payload.access_token : undefined;
    const idToken = typeof payload.id_token === "string" ? payload.id_token : undefined;
    if (!refreshToken && !accessToken) {
        throw new Error("APPLE_TOKEN_EXCHANGE_FAILED");
    }
    return { refreshToken, accessToken, idToken };
}
async function revokeAppleToken(token, tokenTypeHint, config) {
    const clientSecret = createAppleClientSecret(config);
    await postAppleForm(APPLE_REVOKE_URL, {
        client_id: config.clientId,
        client_secret: clientSecret,
        token,
        token_type_hint: tokenTypeHint,
    });
}
function appleSignInDocRef(uid) {
    return admin
        .firestore()
        .collection("users")
        .doc(uid)
        .collection("privateMeta")
        .doc(APPLE_SIGNIN_DOC);
}
async function storeAppleRefreshToken(uid, refreshToken, appleUserId) {
    await appleSignInDocRef(uid).set({
        refreshToken,
        appleUserId: appleUserId ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function loadAppleRefreshToken(uid) {
    const snap = await appleSignInDocRef(uid).get();
    const token = snap.data()?.refreshToken;
    return typeof token === "string" && token.length > 0 ? token : undefined;
}
async function clearAppleRefreshToken(uid) {
    try {
        await appleSignInDocRef(uid).delete();
    }
    catch {
        // Best effort — doc may already be gone via recursiveDelete.
    }
}
async function revokeAppleSignInForUser(uid, config, authorizationCode) {
    let refreshToken = await loadAppleRefreshToken(uid);
    if (!refreshToken && authorizationCode) {
        try {
            const exchanged = await exchangeAuthorizationCode(authorizationCode, config);
            if (exchanged.refreshToken) {
                refreshToken = exchanged.refreshToken;
            }
            else if (exchanged.accessToken) {
                await revokeAppleToken(exchanged.accessToken, "access_token", config);
                await clearAppleRefreshToken(uid);
                return { revoked: true, reason: "access_token" };
            }
        }
        catch (error) {
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
    }
    catch (error) {
        console.error("[appleSignIn] revoke failed", error?.message ?? error);
        return { revoked: false, reason: error?.message ?? "REVOKE_FAILED" };
    }
}
async function registerAppleAuthorizationCode(uid, authorizationCode, config, appleUserId) {
    const exchanged = await exchangeAuthorizationCode(authorizationCode, config);
    if (!exchanged.refreshToken) {
        throw new Error("APPLE_REFRESH_TOKEN_MISSING");
    }
    await storeAppleRefreshToken(uid, exchanged.refreshToken, appleUserId);
}
//# sourceMappingURL=appleSignIn.js.map