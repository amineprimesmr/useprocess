"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.affiliateMcp = exports.affiliateLibrary = exports.affiliateLeaderboard = exports.affiliateTikTokOAuthCallback = exports.affiliateTikTokStudio = exports.affiliateReleaseHeldCommissions = exports.affiliateAdminMarkPaid = exports.affiliateAdminListPending = exports.affiliateAdminApprove = exports.affiliateAdminProvisionAuth = exports.affiliateAdminCreate = exports.affiliateDashboard = exports.affiliateSyncProfile = exports.affiliateApply = exports.affiliateRegister = exports.affiliateTrackFunnel = exports.affiliateTrackLink = exports.affiliateSetLoginEmail = exports.affiliatePortalHandoffRedeem = exports.affiliatePortalHandoff = exports.affiliateSendLoginEmail = exports.affiliatePreparePasswordless = exports.affiliateResolveCode = exports.affiliateRevenueCatWebhook = void 0;
const https_1 = require("firebase-functions/v2/https");
const referralShared_1 = require("./referralShared");
// No account, payout or commission records are deleted by retiring the service.
const retired = (0, https_1.onRequest)({ invoker: "public", cors: true }, (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    res.status(410).json({ error: "CLIPPER_PROGRAM_RETIRED" });
});
// Acknowledge old webhook deliveries without creating further commissions.
exports.affiliateRevenueCatWebhook = (0, https_1.onRequest)({ invoker: "public" }, (_req, res) => {
    res.status(200).json({ ok: true, skipped: "CLIPPER_PROGRAM_RETIRED" });
});
// Kept for released clients that use this URL to validate friend-referral codes.
exports.affiliateResolveCode = (0, https_1.onRequest)({ invoker: "public", cors: true }, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "METHOD_NOT_ALLOWED" });
        return;
    }
    try {
        const raw = String(req.body?.code ?? "").trim().toUpperCase();
        if (!/^[A-Z0-9]{5}$/.test(raw)) {
            res.status(404).json({ error: "CODE_NOT_FOUND" });
            return;
        }
        const code = (0, referralShared_1.normalizeReferralCode)(raw);
        const uid = await (0, referralShared_1.resolveReferrerUserId)(code);
        if (!uid) {
            res.status(404).json({ error: "CODE_NOT_FOUND" });
            return;
        }
        res.status(200).json({ ok: true, type: "referral", code });
    }
    catch {
        res.status(500).json({ error: "RESOLVE_FAILED" });
    }
});
exports.affiliatePreparePasswordless = retired;
exports.affiliateSendLoginEmail = retired;
exports.affiliatePortalHandoff = retired;
exports.affiliatePortalHandoffRedeem = retired;
exports.affiliateSetLoginEmail = retired;
exports.affiliateTrackLink = retired;
exports.affiliateTrackFunnel = retired;
exports.affiliateRegister = retired;
exports.affiliateApply = retired;
exports.affiliateSyncProfile = retired;
exports.affiliateDashboard = retired;
exports.affiliateAdminCreate = retired;
exports.affiliateAdminProvisionAuth = retired;
exports.affiliateAdminApprove = retired;
exports.affiliateAdminListPending = retired;
exports.affiliateAdminMarkPaid = retired;
exports.affiliateReleaseHeldCommissions = retired;
exports.affiliateTikTokStudio = retired;
exports.affiliateTikTokOAuthCallback = retired;
exports.affiliateLeaderboard = retired;
exports.affiliateLibrary = retired;
exports.affiliateMcp = retired;
//# sourceMappingURL=clipperRetired.js.map