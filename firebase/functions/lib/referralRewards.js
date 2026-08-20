"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.referralRevenueCatWebhook = exports.referralConfirmSubscription = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const affiliateShared_1 = require("./affiliateShared");
const revenueCat_1 = require("./revenueCat");
const referralShared_1 = require("./referralShared");
const revenueCatSecretKey = (0, params_1.defineSecret)("REVENUECAT_SECRET_API_KEY");
const revenueCatWebhookSecret = (0, params_1.defineSecret)("REVENUECAT_WEBHOOK_SECRET");
function isReferralRewardEvent(eventType, event) {
    const isInitialPaid = eventType === "INITIAL_PURCHASE" && (0, revenueCat_1.isPaidPurchaseEvent)(event);
    const isLifetime = eventType === "NON_RENEWING_PURCHASE";
    const isTrialConversion = eventType === "RENEWAL" && event?.is_trial_conversion === true;
    return isInitialPaid || isLifetime || isTrialConversion;
}
function isSkippedReferralError(message) {
    return (message === "NOT_REFERRED" ||
        message === "ALREADY_REWARDED" ||
        message === "SUBSCRIPTION_REQUIRED");
}
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
        if (isSkippedReferralError(message)) {
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
    memory: "512MiB",
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
        const eventType = String(event?.type ?? "");
        const appUserId = String(event?.app_user_id ?? "").trim();
        if (!appUserId) {
            res.status(200).json({ ok: true, skipped: "NO_APP_USER_ID" });
            return;
        }
        if (eventType === "REFUND") {
            const affiliate = await (0, affiliateShared_1.clawbackAffiliateCommission)({
                inviteeUid: appUserId,
                event,
            });
            res.status(200).json({ ok: true, affiliate });
            return;
        }
        if (eventType === "CANCELLATION" || eventType === "EXPIRATION") {
            await (0, affiliateShared_1.markAffiliateAttributionChurned)(appUserId);
            res.status(200).json({ ok: true, status: eventType });
            return;
        }
        if (!isReferralRewardEvent(eventType, event)) {
            res.status(200).json({ ok: true, skipped: eventType || "UNKNOWN_EVENT" });
            return;
        }
        let referral = { skipped: "NOT_ATTEMPTED" };
        try {
            const rewards = await (0, referralShared_1.processReferralRewards)({
                referredUserId: appUserId,
                secretKey: revenueCatSecretKey.value(),
            });
            referral = { ok: true, rewards };
        }
        catch (error) {
            const message = error?.message ?? "Unknown error";
            if (isSkippedReferralError(message)) {
                referral = { skipped: message };
            }
            else {
                throw error;
            }
        }
        const affiliate = await (0, affiliateShared_1.accrueAffiliateCommission)({
            inviteeUid: appUserId,
            event,
        });
        res.status(200).json({ ok: true, referral, affiliate });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[referralRevenueCatWebhook]", message);
        res.status(500).json({ error: message });
    }
});
//# sourceMappingURL=referralRewards.js.map