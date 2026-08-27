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
exports.affiliateReleaseHeldCommissions = exports.affiliateRevenueCatWebhook = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const affiliateShared_1 = require("./affiliateShared");
const referralShared_1 = require("./referralShared");
const revenueCatWebhookSecret = (0, params_1.defineSecret)("REVENUECAT_WEBHOOK_SECRET");
const affiliateAdminSecret = (0, params_1.defineSecret)("AFFILIATE_ADMIN_SECRET");
exports.affiliateRevenueCatWebhook = (0, https_1.onRequest)({
    invoker: "public",
    cors: false,
    secrets: [revenueCatWebhookSecret],
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
            const result = await (0, affiliateShared_1.clawbackAffiliateCommission)({
                inviteeUid: appUserId,
                event,
            });
            res.status(200).json({ ok: true, clawed: result.clawed });
            return;
        }
        if (eventType === "CANCELLATION" || eventType === "EXPIRATION") {
            await (0, affiliateShared_1.markAffiliateAttributionChurned)(appUserId);
            res.status(200).json({ ok: true, status: eventType });
            return;
        }
        // Trials pay nothing, so accrual ignores them — count them here instead.
        const trial = await (0, affiliateShared_1.recordAffiliateTrialStart)({ inviteeUid: appUserId, event });
        const result = await (0, affiliateShared_1.accrueAffiliateCommission)({
            inviteeUid: appUserId,
            event,
        });
        res.status(200).json({ ok: true, trial, ...result });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateRevenueCatWebhook]", message);
        res.status(500).json({ error: message });
    }
});
exports.affiliateReleaseHeldCommissions = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
    timeoutSeconds: 120,
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
        const { releaseDueAffiliateCommissions } = await Promise.resolve().then(() => __importStar(require("./affiliateShared")));
        (0, affiliateShared_1.verifyAffiliateAdmin)(req, affiliateAdminSecret.value());
        const affiliateId = String(req.body?.affiliateId ?? "").trim() || undefined;
        const released = await releaseDueAffiliateCommissions(affiliateId);
        res.status(200).json({ ok: true, released });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateReleaseHeldCommissions]", message);
        res.status(500).json({ error: message });
    }
});
//# sourceMappingURL=affiliateCommissions.js.map