"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.referralRevenueCatWebhook = exports.referralConfirmSubscription = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const referralShared_1 = require("./referralShared");
const revenueCatSecretKey = (0, params_1.defineSecret)("REVENUECAT_SECRET_API_KEY");
const revenueCatWebhookSecret = (0, params_1.defineSecret)("REVENUECAT_WEBHOOK_SECRET");
exports.referralConfirmSubscription = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [revenueCatSecretKey],
    timeoutSeconds: 60,
    memory: "256MiB",
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
        const rewards = await (0, referralShared_1.processReferralRewards)({
            referredUserId: uid,
            secretKey: revenueCatSecretKey.value(),
        });
        res.status(200).json({ ok: true, rewards });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        if (message === "NOT_REFERRED" || message === "ALREADY_REWARDED") {
            res.status(200).json({ ok: true, skipped: message });
            return;
        }
        console.error("[referralConfirmSubscription]", message);
        res.status((0, referralShared_1.httpStatusForError)(message)).json({ error: message });
    }
});
exports.referralRevenueCatWebhook = (0, https_1.onRequest)({
    invoker: "public",
    cors: false,
    secrets: [revenueCatSecretKey, revenueCatWebhookSecret],
    timeoutSeconds: 60,
    memory: "256MiB",
}, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const authHeader = String(req.headers.authorization ?? "");
        const expected = `Bearer ${revenueCatWebhookSecret.value()}`;
        if (authHeader !== expected) {
            res.status(401).json({ error: "UNAUTHORIZED" });
            return;
        }
        const event = req.body?.event;
        const eventType = event?.type;
        const appUserId = event?.app_user_id;
        if (!appUserId) {
            res.status(200).json({ ok: true, skipped: "NO_APP_USER_ID" });
            return;
        }
        const purchaseEvents = new Set([
            "INITIAL_PURCHASE",
            "NON_RENEWING_PURCHASE",
            "RENEWAL",
        ]);
        if (!eventType || !purchaseEvents.has(eventType)) {
            res.status(200).json({ ok: true, skipped: eventType ?? "UNKNOWN_EVENT" });
            return;
        }
        if (eventType !== "INITIAL_PURCHASE" && eventType !== "NON_RENEWING_PURCHASE") {
            res.status(200).json({ ok: true, skipped: eventType });
            return;
        }
        const rewards = await (0, referralShared_1.processReferralRewards)({
            referredUserId: appUserId,
            secretKey: revenueCatSecretKey.value(),
        });
        res.status(200).json({ ok: true, rewards });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        if (message === "NOT_REFERRED" ||
            message === "ALREADY_REWARDED" ||
            message === "SUBSCRIPTION_REQUIRED") {
            res.status(200).json({ ok: true, skipped: message });
            return;
        }
        console.error("[referralRevenueCatWebhook]", message);
        res.status(500).json({ error: message });
    }
});
//# sourceMappingURL=referralRewards.js.map