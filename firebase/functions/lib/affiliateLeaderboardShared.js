"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CLIPPER_SORTS = void 0;
exports.normalizeClipperSort = normalizeClipperSort;
exports.clipperMetric = clipperMetric;
exports.toPublicClipper = toPublicClipper;
exports.rankClippers = rankClippers;
exports.CLIPPER_SORTS = ["earnings", "sales", "installs", "visits", "paywalls"];
function num(value) {
    const n = Number(value);
    return Number.isFinite(n) ? Math.max(0, Math.round(n)) : 0;
}
function normalizeClipperSort(raw) {
    const value = String(raw || "").trim();
    return exports.CLIPPER_SORTS.includes(value) ? value : "earnings";
}
function clipperMetric(stats, sort) {
    switch (sort) {
        case "sales":
            return stats.paidCount;
        case "installs":
            return stats.referredCount;
        case "visits":
            return stats.linkViews;
        case "paywalls":
            return stats.paywallCount;
        default:
            return stats.lifetimeCents;
    }
}
function toPublicClipper(params) {
    const statsRaw = params.stats && typeof params.stats === "object" ? params.stats : {};
    const codes = Array.isArray(params.codes)
        ? params.codes.map((value) => String(value || "").trim()).filter(Boolean)
        : [];
    const code = String(params.primaryCode || codes[0] || "")
        .trim()
        .slice(0, 40);
    const displayName = String(params.displayName || "")
        .trim()
        .slice(0, 80) ||
        code ||
        "Clipper";
    return {
        displayName,
        code,
        isYou: Boolean(params.affiliateId) && params.affiliateId === params.viewerAffiliateId,
        stats: {
            lifetimeCents: num(statsRaw.lifetimeCents),
            paidCount: num(statsRaw.paidCount),
            referredCount: num(statsRaw.referredCount),
            linkViews: num(statsRaw.linkViews),
            paywallCount: num(statsRaw.paywallCount),
        },
    };
}
function rankClippers(rows, sort = "earnings") {
    const sorted = [...rows].sort((a, b) => {
        const primary = clipperMetric(b.stats, sort) - clipperMetric(a.stats, sort);
        if (primary)
            return primary;
        const earnings = b.stats.lifetimeCents - a.stats.lifetimeCents;
        if (earnings)
            return earnings;
        const sales = b.stats.paidCount - a.stats.paidCount;
        if (sales)
            return sales;
        const installs = b.stats.referredCount - a.stats.referredCount;
        if (installs)
            return installs;
        const visits = b.stats.linkViews - a.stats.linkViews;
        if (visits)
            return visits;
        return a.displayName.localeCompare(b.displayName, "en", { sensitivity: "base" });
    });
    return sorted.map((row, index) => ({ ...row, rank: index + 1 }));
}
//# sourceMappingURL=affiliateLeaderboardShared.js.map