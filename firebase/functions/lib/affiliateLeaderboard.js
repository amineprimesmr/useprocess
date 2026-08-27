"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.affiliateLeaderboard = void 0;
const https_1 = require("firebase-functions/v2/https");
const affiliateShared_1 = require("./affiliateShared");
const affiliateLeaderboardShared_1 = require("./affiliateLeaderboardShared");
const referralShared_1 = require("./referralShared");
const LEADERBOARD_LIMIT = 400;
exports.affiliateLeaderboard = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 20,
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
        const affiliate = await (0, affiliateShared_1.resolveAffiliateForAuthUser)(uid);
        if (!affiliate) {
            res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
            return;
        }
        const sort = (0, affiliateLeaderboardShared_1.normalizeClipperSort)(req.body?.sort);
        const snap = await (0, affiliateShared_1.db)()
            .collection("affiliates")
            .where("status", "==", "active")
            .limit(LEADERBOARD_LIMIT)
            .get();
        const rows = snap.docs.map((doc) => {
            const data = doc.data();
            return (0, affiliateLeaderboardShared_1.toPublicClipper)({
                affiliateId: doc.id,
                viewerAffiliateId: affiliate.affiliateId,
                displayName: data.displayName,
                primaryCode: data.primaryCode,
                codes: data.codes,
                stats: data.stats,
            });
        });
        if (affiliate.status === "active" && !rows.some((row) => row.isYou)) {
            rows.push((0, affiliateLeaderboardShared_1.toPublicClipper)({
                affiliateId: affiliate.affiliateId,
                viewerAffiliateId: affiliate.affiliateId,
                displayName: affiliate.displayName,
                primaryCode: affiliate.primaryCode,
                codes: affiliate.codes,
                stats: affiliate.stats,
            }));
        }
        const clippers = (0, affiliateLeaderboardShared_1.rankClippers)(rows, sort);
        const you = clippers.find((row) => row.isYou) || null;
        res.status(200).json({
            ok: true,
            sort,
            count: clippers.length,
            viewerStatus: affiliate.status,
            you,
            clippers,
        });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateLeaderboard]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
//# sourceMappingURL=affiliateLeaderboard.js.map