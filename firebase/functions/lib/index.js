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
exports.affiliateMcp = exports.affiliateLibrary = exports.affiliateLeaderboard = exports.affiliateTikTokOAuthCallback = exports.affiliateTikTokStudio = exports.supportCrispPoll = exports.supportCrispWebhook = exports.supportSendMessage = exports.affiliateStripeWebhook = exports.affiliateStripeConnectDashboard = exports.affiliateStripeConnectSync = exports.affiliateStripeConnectStart = exports.affiliateReleaseHeldCommissions = exports.affiliateRevenueCatWebhook = exports.affiliateAdminMarkPaid = exports.affiliateAdminListPending = exports.affiliateAdminApprove = exports.affiliateAdminProvisionAuth = exports.affiliateAdminCreate = exports.affiliateDashboard = exports.affiliateSyncProfile = exports.affiliateApply = exports.affiliateRegister = exports.affiliateTrackFunnel = exports.affiliateTrackLink = exports.affiliateResolveCode = exports.affiliatePreparePasswordless = exports.referralRevenueCatWebhook = exports.referralConfirmSubscription = exports.referralDashboard = exports.referralRegister = exports.referralSyncProgram = exports.coachStream = exports.coachComplete = exports.appleSignInRegisterToken = exports.deleteUserAccount = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const sdk_1 = __importDefault(require("@anthropic-ai/sdk"));
const coachValidation_1 = require("./coachValidation");
const premiumAccess_1 = require("./premiumAccess");
const referralShared_1 = require("./referralShared");
const appleSignIn_1 = require("./appleSignIn");
admin.initializeApp();
const anthropicApiKey = (0, params_1.defineSecret)("ANTHROPIC_API_KEY");
const revenueCatSecretKey = (0, params_1.defineSecret)("REVENUECAT_SECRET_API_KEY");
const appleSignInTeamId = (0, params_1.defineSecret)("APPLE_SIGNIN_TEAM_ID");
const appleSignInKeyId = (0, params_1.defineSecret)("APPLE_SIGNIN_KEY_ID");
const appleSignInPrivateKey = (0, params_1.defineSecret)("APPLE_SIGNIN_PRIVATE_KEY");
const APPLE_SIGNIN_SECRETS = [
    appleSignInTeamId,
    appleSignInKeyId,
    appleSignInPrivateKey,
];
function appleSignInConfigFromSecrets() {
    const secrets = {
        teamId: appleSignInTeamId.value(),
        keyId: appleSignInKeyId.value(),
        privateKey: appleSignInPrivateKey.value(),
        clientId: process.env.APPLE_SIGNIN_CLIENT_ID || "com.useprocess",
    };
    return (0, appleSignIn_1.resolveAppleSignInConfig)(secrets);
}
function isAppleSignInProvider(user) {
    return user.providerData.some((provider) => provider.providerId === "apple.com");
}
const enforceAppCheck = process.env.ENFORCE_APP_CHECK === "true";
function setCors(res) {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Firebase-AppCheck");
}
async function verifyFirebaseUser(req) {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
        throw new Error("UNAUTHORIZED");
    }
    const token = header.slice("Bearer ".length);
    const decoded = await admin.auth().verifyIdToken(token);
    return decoded.uid;
}
async function verifyAppAttestation(req) {
    const token = req.header("X-Firebase-AppCheck");
    if (!token) {
        if (enforceAppCheck)
            throw new Error("INVALID_APP_CHECK");
        console.warn("[AppCheck] Missing token (monitoring mode)");
        return;
    }
    try {
        await admin.appCheck().verifyToken(token);
    }
    catch (error) {
        if (enforceAppCheck)
            throw new Error("INVALID_APP_CHECK");
        console.warn("[AppCheck] Invalid token (monitoring mode)", error);
    }
}
function buildMessages(body) {
    const history = (body.history ?? []).map((m) => ({
        role: m.role,
        content: [{ type: "text", text: m.text }],
    }));
    const last = body.history?.[body.history.length - 1];
    if (last?.role === "user" && last.text === body.userText) {
        return history;
    }
    let userContent;
    if (body.imageBase64) {
        userContent = [
            {
                type: "image",
                source: {
                    type: "base64",
                    media_type: "image/jpeg",
                    data: body.imageBase64,
                },
            },
            { type: "text", text: body.userText },
        ];
    }
    else {
        userContent = [{ type: "text", text: body.userText }];
    }
    return [
        ...history,
        { role: "user", content: userContent },
    ];
}
async function sleep(ms) {
    await new Promise((resolve) => setTimeout(resolve, ms));
}
function isRetryableAnthropicError(error) {
    const message = error?.message?.toLowerCase() ?? "";
    const status = error?.status;
    return (status === 529 ||
        status === 503 ||
        status === 429 ||
        message.includes("overloaded") ||
        message.includes("rate limit"));
}
async function withAnthropicRetry(operation, maxAttempts = 3) {
    let lastError;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
        try {
            return await operation();
        }
        catch (error) {
            lastError = error;
            if (!isRetryableAnthropicError(error) || attempt >= maxAttempts - 1) {
                throw error;
            }
            await sleep(900 * (attempt + 1));
        }
    }
    throw lastError;
}
async function enforceCoachRateLimit(uid) {
    const db = admin.firestore();
    const ref = db
        .collection("users")
        .doc(uid)
        .collection("coachMeta")
        .doc("rateLimit");
    const now = Date.now();
    const day = new Date(now).toISOString().slice(0, 10);
    await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const data = snapshot.data();
        const count = data?.day === day ? Number(data?.count ?? 0) : 0;
        const lastCallAt = data?.lastCallAt?.toMillis?.() ?? 0;
        if (count >= 500 || now - lastCallAt < 750) {
            throw new Error("RATE_LIMITED");
        }
        transaction.set(ref, {
            day,
            count: count + 1,
            lastCallAt: admin.firestore.Timestamp.fromMillis(now),
        }, { merge: true });
    });
}
async function deleteReferralArtifactsForUser(uid) {
    const db = admin.firestore();
    const program = await db
        .collection("users")
        .doc(uid)
        .collection("referralMeta")
        .doc("program")
        .get();
    const rawCode = program.data()?.referralCode;
    if (typeof rawCode === "string" && rawCode.trim()) {
        const normalized = (0, referralShared_1.normalizeReferralCode)(rawCode);
        if (!(0, referralShared_1.isValidReferralCode)(normalized))
            return;
        const codeRef = db.collection("referralCodes").doc(normalized);
        const codeSnap = await codeRef.get();
        if (codeSnap.exists && codeSnap.data()?.userId === uid) {
            await codeRef.delete();
        }
    }
}
async function deleteAllUserFirestoreData(uid) {
    const db = admin.firestore();
    await deleteReferralArtifactsForUser(uid);
    const userRef = db.collection("users").doc(uid);
    // Supprime le document et toutes ses sous-collections, y compris celles
    // qui seront ajoutées plus tard au modèle de données.
    await db.recursiveDelete(userRef);
    const usernames = await db
        .collection("usernames")
        .where("userId", "==", uid)
        .get();
    if (!usernames.empty) {
        const batch = db.batch();
        usernames.docs.forEach((document) => batch.delete(document.ref));
        await batch.commit();
    }
}
exports.deleteUserAccount = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: APPLE_SIGNIN_SECRETS,
    timeoutSeconds: 180,
    memory: "1GiB",
}, async (req, res) => {
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
        const body = (req.body ?? {});
        const appleAuthorizationCode = typeof body.appleAuthorizationCode === "string"
            ? body.appleAuthorizationCode.trim()
            : undefined;
        let appleRevoked;
        let appleRevokeReason;
        try {
            const authUser = await admin.auth().getUser(uid);
            if (isAppleSignInProvider(authUser)) {
                try {
                    const appleConfig = appleSignInConfigFromSecrets();
                    const revokeResult = await (0, appleSignIn_1.revokeAppleSignInForUser)(uid, appleConfig, appleAuthorizationCode);
                    appleRevoked = revokeResult.revoked;
                    appleRevokeReason = revokeResult.reason;
                }
                catch (appleError) {
                    console.warn("[deleteUserAccount] Apple revoke skipped", appleError?.message ?? appleError);
                    appleRevoked = false;
                    appleRevokeReason = appleError?.message ?? "APPLE_CONFIG_UNAVAILABLE";
                }
            }
        }
        catch (authLookupError) {
            console.warn("[deleteUserAccount] auth lookup before Apple revoke", authLookupError?.message ?? authLookupError);
        }
        // Les données sont effacées avant l'identité : aucune réponse positive
        // n'est envoyée si le nettoyage des données personnelles échoue.
        await deleteAllUserFirestoreData(uid);
        try {
            await admin.auth().deleteUser(uid);
        }
        catch (authError) {
            if (authError?.code !== "auth/user-not-found") {
                throw authError;
            }
        }
        console.info("[deleteUserAccount] Deleted user and data", uid, {
            appleRevoked,
            appleRevokeReason,
        });
        res.status(200).json({ ok: true, uid, appleRevoked, appleRevokeReason });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        const status = message === "UNAUTHORIZED" ? 401 : 500;
        console.error("[deleteUserAccount]", message);
        res.status(status).json({ error: message });
    }
});
exports.appleSignInRegisterToken = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: APPLE_SIGNIN_SECRETS,
    timeoutSeconds: 60,
    memory: "256MiB",
}, async (req, res) => {
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
        const body = (req.body ?? {});
        const authorizationCode = typeof body.authorizationCode === "string"
            ? body.authorizationCode.trim()
            : "";
        if (!authorizationCode) {
            res.status(400).json({ error: "Missing authorizationCode" });
            return;
        }
        const appleUserId = typeof body.appleUserId === "string" ? body.appleUserId.trim() : undefined;
        const appleConfig = appleSignInConfigFromSecrets();
        await (0, appleSignIn_1.registerAppleAuthorizationCode)(uid, authorizationCode, appleConfig, appleUserId);
        res.status(200).json({ ok: true, uid });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        const status = message === "UNAUTHORIZED"
            ? 401
            : message.startsWith("APPLE_") || message === "APPLE_SIGNIN_CONFIG_INCOMPLETE"
                ? 503
                : 500;
        console.error("[appleSignInRegisterToken]", message);
        res.status(status).json({ error: message });
    }
});
exports.coachComplete = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [anthropicApiKey, revenueCatSecretKey],
    timeoutSeconds: 120,
    memory: "512MiB",
}, async (req, res) => {
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
        await (0, premiumAccess_1.verifyPremiumSubscriber)(uid, revenueCatSecretKey.value());
        const body = req.body;
        const validationError = (0, coachValidation_1.validateCoachBody)(body);
        if (validationError) {
            res.status(400).json({ error: validationError });
            return;
        }
        await enforceCoachRateLimit(uid);
        const client = new sdk_1.default({ apiKey: anthropicApiKey.value() });
        const model = (0, coachValidation_1.normalizeModel)(body.model);
        const response = await withAnthropicRetry(() => client.messages.create({
            model,
            max_tokens: (0, coachValidation_1.maxTokensForTask)(body.task ?? "chat", body.maxTokens),
            system: body.system,
            messages: buildMessages(body),
        }));
        const text = response.content
            .filter((b) => b.type === "text")
            .map((b) => (b.type === "text" ? b.text : ""))
            .join("\n")
            .trim();
        await admin
            .firestore()
            .collection("users")
            .doc(uid)
            .collection("coachMeta")
            .doc("usage")
            .set({
            lastTask: body.task ?? "chat",
            lastModel: model,
            lastCalledAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        res.status(200).json({ text, model, uid });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        const status = (0, coachValidation_1.httpStatusForError)(message);
        console.error("[coachComplete]", message);
        res.status(status).json({ error: message });
    }
});
exports.coachStream = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [anthropicApiKey, revenueCatSecretKey],
    timeoutSeconds: 180,
    memory: "512MiB",
}, async (req, res) => {
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
        await (0, premiumAccess_1.verifyPremiumSubscriber)(uid, revenueCatSecretKey.value());
        const body = req.body;
        const validationError = (0, coachValidation_1.validateCoachBody)(body);
        if (validationError) {
            res.status(400).json({ error: validationError });
            return;
        }
        await enforceCoachRateLimit(uid);
        res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
        res.setHeader("Cache-Control", "no-cache, no-transform");
        res.setHeader("Connection", "keep-alive");
        const client = new sdk_1.default({ apiKey: anthropicApiKey.value() });
        const model = (0, coachValidation_1.normalizeModel)(body.model);
        const streamParams = {
            model,
            max_tokens: (0, coachValidation_1.maxTokensForTask)(body.task ?? "chat", body.maxTokens),
            system: body.system,
            messages: buildMessages(body),
        };
        let lastStreamError;
        for (let attempt = 0; attempt < 3; attempt++) {
            try {
                const stream = client.messages.stream(streamParams);
                for await (const event of stream) {
                    if (event.type === "content_block_delta" &&
                        event.delta.type === "text_delta") {
                        if (!res.headersSent) {
                            res.flushHeaders?.();
                        }
                        const payload = JSON.stringify({
                            type: "delta",
                            text: event.delta.text,
                        });
                        res.write(`data: ${payload}\n\n`);
                    }
                }
                const finalText = (await stream.finalMessage()).content
                    .filter((b) => b.type === "text")
                    .map((b) => (b.type === "text" ? b.text : ""))
                    .join("\n")
                    .trim();
                if (!res.headersSent) {
                    res.flushHeaders?.();
                }
                res.write(`data: ${JSON.stringify({ type: "done", text: finalText, model, uid })}\n\n`);
                res.end();
                await admin
                    .firestore()
                    .collection("users")
                    .doc(uid)
                    .collection("coachMeta")
                    .doc("usage")
                    .set({
                    lastTask: "chat_stream",
                    lastModel: model,
                    lastStreamAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
                return;
            }
            catch (error) {
                lastStreamError = error;
                const canRetry = !res.headersSent &&
                    isRetryableAnthropicError(error) &&
                    attempt < 2;
                if (!canRetry) {
                    throw error;
                }
                await sleep(900 * (attempt + 1));
            }
        }
        throw lastStreamError;
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[coachStream]", message);
        if (!res.headersSent) {
            res.status((0, coachValidation_1.httpStatusForError)(message)).json({ error: message });
        }
        else {
            res.write(`data: ${JSON.stringify({ type: "error", error: message })}\n\n`);
            res.end();
        }
    }
});
var referral_1 = require("./referral");
Object.defineProperty(exports, "referralSyncProgram", { enumerable: true, get: function () { return referral_1.referralSyncProgram; } });
Object.defineProperty(exports, "referralRegister", { enumerable: true, get: function () { return referral_1.referralRegister; } });
Object.defineProperty(exports, "referralDashboard", { enumerable: true, get: function () { return referral_1.referralDashboard; } });
var referralRewards_1 = require("./referralRewards");
Object.defineProperty(exports, "referralConfirmSubscription", { enumerable: true, get: function () { return referralRewards_1.referralConfirmSubscription; } });
Object.defineProperty(exports, "referralRevenueCatWebhook", { enumerable: true, get: function () { return referralRewards_1.referralRevenueCatWebhook; } });
var affiliate_1 = require("./affiliate");
Object.defineProperty(exports, "affiliatePreparePasswordless", { enumerable: true, get: function () { return affiliate_1.affiliatePreparePasswordless; } });
Object.defineProperty(exports, "affiliateResolveCode", { enumerable: true, get: function () { return affiliate_1.affiliateResolveCode; } });
Object.defineProperty(exports, "affiliateTrackLink", { enumerable: true, get: function () { return affiliate_1.affiliateTrackLink; } });
Object.defineProperty(exports, "affiliateTrackFunnel", { enumerable: true, get: function () { return affiliate_1.affiliateTrackFunnel; } });
Object.defineProperty(exports, "affiliateRegister", { enumerable: true, get: function () { return affiliate_1.affiliateRegister; } });
Object.defineProperty(exports, "affiliateApply", { enumerable: true, get: function () { return affiliate_1.affiliateApply; } });
Object.defineProperty(exports, "affiliateSyncProfile", { enumerable: true, get: function () { return affiliate_1.affiliateSyncProfile; } });
Object.defineProperty(exports, "affiliateDashboard", { enumerable: true, get: function () { return affiliate_1.affiliateDashboard; } });
Object.defineProperty(exports, "affiliateAdminCreate", { enumerable: true, get: function () { return affiliate_1.affiliateAdminCreate; } });
Object.defineProperty(exports, "affiliateAdminProvisionAuth", { enumerable: true, get: function () { return affiliate_1.affiliateAdminProvisionAuth; } });
Object.defineProperty(exports, "affiliateAdminApprove", { enumerable: true, get: function () { return affiliate_1.affiliateAdminApprove; } });
Object.defineProperty(exports, "affiliateAdminListPending", { enumerable: true, get: function () { return affiliate_1.affiliateAdminListPending; } });
Object.defineProperty(exports, "affiliateAdminMarkPaid", { enumerable: true, get: function () { return affiliate_1.affiliateAdminMarkPaid; } });
var affiliateCommissions_1 = require("./affiliateCommissions");
Object.defineProperty(exports, "affiliateRevenueCatWebhook", { enumerable: true, get: function () { return affiliateCommissions_1.affiliateRevenueCatWebhook; } });
Object.defineProperty(exports, "affiliateReleaseHeldCommissions", { enumerable: true, get: function () { return affiliateCommissions_1.affiliateReleaseHeldCommissions; } });
var affiliateStripe_1 = require("./affiliateStripe");
Object.defineProperty(exports, "affiliateStripeConnectStart", { enumerable: true, get: function () { return affiliateStripe_1.affiliateStripeConnectStart; } });
Object.defineProperty(exports, "affiliateStripeConnectSync", { enumerable: true, get: function () { return affiliateStripe_1.affiliateStripeConnectSync; } });
Object.defineProperty(exports, "affiliateStripeConnectDashboard", { enumerable: true, get: function () { return affiliateStripe_1.affiliateStripeConnectDashboard; } });
Object.defineProperty(exports, "affiliateStripeWebhook", { enumerable: true, get: function () { return affiliateStripe_1.affiliateStripeWebhook; } });
var supportCrisp_1 = require("./supportCrisp");
Object.defineProperty(exports, "supportSendMessage", { enumerable: true, get: function () { return supportCrisp_1.supportSendMessage; } });
Object.defineProperty(exports, "supportCrispWebhook", { enumerable: true, get: function () { return supportCrisp_1.supportCrispWebhook; } });
Object.defineProperty(exports, "supportCrispPoll", { enumerable: true, get: function () { return supportCrisp_1.supportCrispPoll; } });
var affiliateTikTok_1 = require("./affiliateTikTok");
Object.defineProperty(exports, "affiliateTikTokStudio", { enumerable: true, get: function () { return affiliateTikTok_1.affiliateTikTokStudio; } });
Object.defineProperty(exports, "affiliateTikTokOAuthCallback", { enumerable: true, get: function () { return affiliateTikTok_1.affiliateTikTokOAuthCallback; } });
var affiliateLeaderboard_1 = require("./affiliateLeaderboard");
Object.defineProperty(exports, "affiliateLeaderboard", { enumerable: true, get: function () { return affiliateLeaderboard_1.affiliateLeaderboard; } });
var affiliateLibrary_1 = require("./affiliateLibrary");
Object.defineProperty(exports, "affiliateLibrary", { enumerable: true, get: function () { return affiliateLibrary_1.affiliateLibrary; } });
var affiliateMcp_1 = require("./affiliateMcp");
Object.defineProperty(exports, "affiliateMcp", { enumerable: true, get: function () { return affiliateMcp_1.affiliateMcp; } });
//# sourceMappingURL=index.js.map