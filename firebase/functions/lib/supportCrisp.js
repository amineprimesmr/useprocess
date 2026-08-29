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
Object.defineProperty(exports, "__esModule", { value: true });
exports.supportCrispWebhook = exports.supportCrispPoll = exports.supportSendMessage = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const params_1 = require("firebase-functions/params");
const referralShared_1 = require("./referralShared");
/**
 * Inbox opérateur = Crisp. L’app n’ouvre plus le ChatViewController Crisp.
 *
 * Secrets Firebase (à setter une fois) :
 *   firebase functions:secrets:set CRISP_IDENTIFIER
 *   firebase functions:secrets:set CRISP_KEY
 *   firebase functions:secrets:set CRISP_WEBHOOK_SECRET
 *
 * Jeton : Crisp → Paramètres → Paramètres du workspace → Configuration avancée → API Token.
 * Webhook : même écran → Web Hooks, URL
 *   https://us-central1-useprocess-d4385.cloudfunctions.net/supportCrispWebhook?token=CRISP_WEBHOOK_SECRET
 * Events : message:send, message:received
 */
const DEFAULT_WEBSITE_ID = "eabb57a7-e62e-46fa-9778-99601f5b84ac";
const MAX_TEXT_LENGTH = 4000;
const MIN_SEND_INTERVAL_MS = 1200;
const crispIdentifier = (0, params_1.defineSecret)("CRISP_IDENTIFIER");
const crispKey = (0, params_1.defineSecret)("CRISP_KEY");
const crispWebhookSecret = (0, params_1.defineSecret)("CRISP_WEBHOOK_SECRET");
const CRISP_SECRETS = [crispIdentifier, crispKey, crispWebhookSecret];
function websiteId() {
    const fromEnv = String(process.env.CRISP_WEBSITE_ID ?? "").trim();
    if (fromEnv && !fromEnv.startsWith("YOUR_"))
        return fromEnv;
    return DEFAULT_WEBSITE_ID;
}
function supportMessages(uid) {
    return (0, referralShared_1.db)().collection("users").doc(uid).collection("supportMessages");
}
function threadRef(uid) {
    return (0, referralShared_1.db)().collection("users").doc(uid).collection("supportMeta").doc("thread");
}
function sessionIndexRef(sessionId) {
    return (0, referralShared_1.db)().collection("crispSessions").doc(sessionId);
}
function extractText(content) {
    if (typeof content === "string") {
        const trimmed = content.trim();
        return trimmed || null;
    }
    if (content && typeof content === "object") {
        const value = content;
        if (typeof value.text === "string" && value.text.trim())
            return value.text.trim();
        if (typeof value.message === "string" && value.message.trim())
            return value.message.trim();
        if (typeof value.url === "string" && value.url.trim())
            return value.url.trim();
    }
    return null;
}
function webhookTokenFromRequest(req) {
    const queryToken = String(req.query?.token ?? "").trim();
    if (queryToken)
        return queryToken;
    const header = String(req.headers["x-crisp-webhook-token"] ?? "").trim();
    return header;
}
async function crispRequest(method, path, body) {
    const identifier = crispIdentifier.value();
    const key = crispKey.value();
    if (!identifier || !key) {
        throw new Error("CRISP_UNAVAILABLE");
    }
    const auth = Buffer.from(`${identifier}:${key}`).toString("base64");
    const response = await fetch(`https://api.crisp.chat/v1${path}`, {
        method,
        headers: {
            Authorization: `Basic ${auth}`,
            "Content-Type": "application/json",
            "X-Crisp-Tier": "website",
        },
        body: body === undefined ? undefined : JSON.stringify(body),
    });
    const json = (await response.json().catch(() => ({})));
    if (!response.ok || json.error) {
        const reason = json.reason || response.statusText || "error";
        console.error("[Crisp]", method, path, response.status, reason);
        throw new Error(`CRISP_${response.status}:${reason}`);
    }
    return json.data;
}
async function createCrispSession() {
    const data = await crispRequest("POST", `/website/${websiteId()}/conversation`);
    const sessionId = String(data?.session_id ?? "").trim();
    if (!sessionId)
        throw new Error("CRISP_UNAVAILABLE");
    return sessionId;
}
async function patchConversationMeta(sessionId, meta) {
    const payload = {
        nickname: meta.nickname || "Process",
        segments: ["ios_app"],
        data: {
            user_id: meta.userId,
            app_language: meta.language || "",
            subscription: meta.subscription || "",
            acquisition_source: meta.acquisitionSource || "",
            app_version: meta.appVersion || "",
        },
    };
    if (meta.email && meta.email.includes("@")) {
        payload.email = meta.email;
    }
    try {
        await crispRequest("PATCH", `/website/${websiteId()}/conversation/${sessionId}/meta`, payload);
    }
    catch (error) {
        console.warn("[Crisp] meta patch failed", error);
    }
}
async function sendCrispUserMessage(sessionId, text) {
    return sendCrispMessage(sessionId, "user", "text", text);
}
async function sendCrispMessage(sessionId, from, type, text) {
    const data = await crispRequest("POST", `/website/${websiteId()}/conversation/${sessionId}/message`, {
        type,
        from,
        origin: "chat",
        content: text,
    });
    return typeof data?.fingerprint === "number" ? data.fingerprint : null;
}
async function reopenConversation(sessionId) {
    try {
        await crispRequest("PATCH", `/website/${websiteId()}/conversation/${sessionId}/state`, { state: "unresolved" });
    }
    catch {
        // Conversation already open, or plugin cannot change state.
    }
}
function isMissingSessionError(error) {
    const message = error instanceof Error ? error.message : String(error);
    return (message.includes("CRISP_404") ||
        message.toLowerCase().includes("not_found") ||
        message.toLowerCase().includes("session"));
}
async function resolveSessionId(uid) {
    const snap = await threadRef(uid).get();
    const existing = String(snap.data()?.crispSessionId ?? "").trim();
    if (existing) {
        return { sessionId: existing, created: false };
    }
    const sessionId = await createCrispSession();
    await sessionIndexRef(sessionId).set({
        userId: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { sessionId, created: true };
}
exports.supportSendMessage = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: CRISP_SECRETS,
    timeoutSeconds: 60,
    memory: "512MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const uid = await (0, referralShared_1.verifyFirebaseUser)(req);
        await (0, referralShared_1.verifyAppAttestation)(req);
        const text = String(req.body?.text ?? "").trim();
        if (!text || text.length > MAX_TEXT_LENGTH) {
            throw new Error("INVALID_TEXT");
        }
        const clientMessageId = String(req.body?.messageId ?? "").trim();
        const messageId = /^[A-Za-z0-9_-]{8,64}$/.test(clientMessageId)
            ? clientMessageId
            : (0, referralShared_1.db)().collection("_").doc().id;
        const threadSnap = await threadRef(uid).get();
        const lastSentAt = threadSnap.data()?.lastSentAt;
        if (lastSentAt?.toMillis && Date.now() - lastSentAt.toMillis() < MIN_SEND_INTERVAL_MS) {
            throw new Error("RATE_LIMITED");
        }
        let { sessionId } = await resolveSessionId(uid);
        const authUser = await admin.auth().getUser(uid).catch(() => null);
        const nickname = String(req.body?.nickname ?? authUser?.displayName ?? "").trim();
        const email = String(req.body?.email ?? authUser?.email ?? "").trim();
        await patchConversationMeta(sessionId, {
            userId: uid,
            nickname,
            email,
            language: String(req.body?.language ?? "").trim(),
            subscription: String(req.body?.subscription ?? "").trim(),
            acquisitionSource: String(req.body?.acquisitionSource ?? "").trim(),
            appVersion: String(req.body?.appVersion ?? "").trim(),
        });
        let fingerprint = null;
        try {
            await reopenConversation(sessionId);
            fingerprint = await sendCrispUserMessage(sessionId, text);
        }
        catch (error) {
            if (!isMissingSessionError(error))
                throw error;
            sessionId = await createCrispSession();
            await sessionIndexRef(sessionId).set({
                userId: uid,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            await patchConversationMeta(sessionId, {
                userId: uid,
                nickname,
                email,
                language: String(req.body?.language ?? "").trim(),
                subscription: String(req.body?.subscription ?? "").trim(),
                acquisitionSource: String(req.body?.acquisitionSource ?? "").trim(),
                appVersion: String(req.body?.appVersion ?? "").trim(),
            });
            fingerprint = await sendCrispUserMessage(sessionId, text);
        }
        const now = admin.firestore.FieldValue.serverTimestamp();
        await supportMessages(uid).doc(messageId).set({
            text,
            from: "user",
            createdAt: now,
            origin: "app",
            crispFingerprint: fingerprint,
        });
        await threadRef(uid).set({
            crispSessionId: sessionId,
            updatedAt: now,
            lastSentAt: now,
            lastFrom: "user",
        }, { merge: true });
        res.status(200).json({ ok: true, messageId, sessionId });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Unknown error";
        console.error("[supportSendMessage]", message);
        const status = message.startsWith("CRISP_")
            ? 503
            : (0, referralShared_1.httpStatusForError)(message);
        res.status(status).json({ error: message.startsWith("CRISP_") ? "CRISP_UNAVAILABLE" : message });
    }
});
async function persistOperatorMessage(params) {
    let userId = String(params.userId ?? "").trim();
    if (!userId) {
        const index = await sessionIndexRef(params.sessionId).get();
        userId = String(index.data()?.userId ?? "").trim();
    }
    if (!userId) {
        console.warn("[supportCrisp] unknown session", params.sessionId);
        return false;
    }
    await sessionIndexRef(params.sessionId).set({
        userId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const messageId = params.fingerprint != null
        ? `op-${params.fingerprint}`
        : `op-${params.sessionId}-${params.timestampMs || Date.now()}`;
    const doc = supportMessages(userId).doc(messageId);
    const existing = await doc.get();
    if (existing.exists)
        return false;
    const createdAt = params.timestampMs
        ? admin.firestore.Timestamp.fromMillis(params.timestampMs)
        : admin.firestore.FieldValue.serverTimestamp();
    await doc.set({
        text: params.text,
        from: "operator",
        createdAt,
        origin: params.origin || "crisp",
        crispFingerprint: params.fingerprint,
        crispSessionId: params.sessionId,
    });
    await threadRef(userId).set({
        crispSessionId: params.sessionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastFrom: "operator",
    }, { merge: true });
    return true;
}
async function ingestOperatorMessagesForSession(sessionId, userId) {
    const messages = await crispRequest("GET", `/website/${websiteId()}/conversation/${sessionId}/messages`);
    let stored = 0;
    for (const message of Array.isArray(messages) ? messages : []) {
        if (String(message.from ?? "") !== "operator")
            continue;
        const type = String(message.type ?? "text");
        if (type === "note" || type === "event")
            continue;
        const text = extractText(message.content);
        if (!text)
            continue;
        const created = await persistOperatorMessage({
            sessionId,
            text,
            fingerprint: typeof message.fingerprint === "number" ? message.fingerprint : null,
            timestampMs: typeof message.timestamp === "number" ? message.timestamp : null,
            userId,
        });
        if (created)
            stored += 1;
    }
    return stored;
}
exports.supportCrispPoll = (0, scheduler_1.onSchedule)({
    schedule: "every 1 minutes",
    timeZone: "Europe/Paris",
    secrets: CRISP_SECRETS,
    timeoutSeconds: 60,
    memory: "256MiB",
}, async () => {
    const listed = await crispRequest("GET", `/website/${websiteId()}/conversations/1`);
    const conversations = Array.isArray(listed) ? listed : [];
    const now = Date.now();
    let fetched = 0;
    for (const conv of conversations) {
        const sessionId = String(conv.session_id ?? "").trim();
        if (!sessionId)
            continue;
        const metaUserId = String(conv.meta?.data?.user_id ?? "").trim();
        const index = await sessionIndexRef(sessionId).get();
        const userId = metaUserId || String(index.data()?.userId ?? "").trim();
        if (!userId)
            continue;
        const unreadVisitor = Number(conv.unread?.visitor ?? 0);
        const recentlyUpdated = typeof conv.updated_at === "number" && now - conv.updated_at < 15 * 60 * 1000;
        if (unreadVisitor <= 0 && !recentlyUpdated)
            continue;
        if (fetched >= 6)
            break;
        fetched += 1;
        try {
            await ingestOperatorMessagesForSession(sessionId, userId);
        }
        catch (error) {
            console.warn("[supportCrispPoll] session failed", sessionId, error);
        }
    }
});
function readWebhookEvents(body) {
    if (!body || typeof body !== "object")
        return [];
    const payload = body;
    if (Array.isArray(payload.events)) {
        return payload.events.filter((item) => item && typeof item === "object");
    }
    if (typeof payload.event === "string") {
        return [payload];
    }
    if (payload.session_id && payload.from) {
        return [{ event: "message:send", data: payload }];
    }
    return [];
}
function eventData(event) {
    if (event.data && typeof event.data === "object") {
        return event.data;
    }
    return event;
}
exports.supportCrispWebhook = (0, https_1.onRequest)({
    invoker: "public",
    cors: false,
    secrets: CRISP_SECRETS,
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (req, res) => {
    if (req.method === "GET") {
        res.status(200).json({ ok: true });
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const expected = crispWebhookSecret.value();
        const provided = webhookTokenFromRequest(req);
        if (!expected || provided !== expected) {
            res.status(401).json({ error: "UNAUTHORIZED" });
            return;
        }
        const events = readWebhookEvents(req.body);
        for (const event of events) {
            const name = String(event.event ?? "").trim();
            if (name && name !== "message:send" && name !== "message:received") {
                continue;
            }
            const data = eventData(event);
            const from = String(data.from ?? "").trim();
            if (from !== "operator")
                continue;
            const type = String(data.type ?? "text").trim();
            if (type === "note" || type === "event")
                continue;
            const text = extractText(data.content);
            if (!text)
                continue;
            const sessionId = String(data.session_id ?? "").trim();
            if (!sessionId)
                continue;
            const eventWebsiteId = String(data.website_id ?? event.website_id ?? "").trim();
            if (eventWebsiteId && eventWebsiteId !== websiteId())
                continue;
            const fingerprint = typeof data.fingerprint === "number" ? data.fingerprint : null;
            const timestampMs = typeof data.timestamp === "number" ? data.timestamp : null;
            await persistOperatorMessage({
                sessionId,
                text,
                fingerprint,
                timestampMs,
            });
        }
        res.status(200).json({ ok: true });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Unknown error";
        console.error("[supportCrispWebhook]", message);
        res.status(500).json({ error: "WEBHOOK_FAILED" });
    }
});
//# sourceMappingURL=supportCrisp.js.map