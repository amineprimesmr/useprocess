"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EMPTY_DAILY_COUNTS = void 0;
exports.utcDayKey = utcDayKey;
exports.utcHourKey = utcHourKey;
exports.lastNDayKeys = lastNDayKeys;
exports.hashKey = hashKey;
exports.sanitizeVisitorId = sanitizeVisitorId;
exports.isLikelyBotUserAgent = isLikelyBotUserAgent;
exports.emptyDailySeries = emptyDailySeries;
const node_crypto_1 = require("node:crypto");
const BOT_UA = /\b(bot|crawler|spider|crawling|preview|facebookexternalhit|facebot|twitterbot|slackbot|telegrambot|whatsapp|linkedinbot|googlebot|bingbot|applebot|duckduckbot|yandexbot|baiduspider|bytespider|gptbot|chatgpt|claudebot|meta-externalagent|pingdom|uptimerobot)\b/i;
const MOBILE_UA = /\b(iphone|ipad|ipod|android|mobile|tiktok|musical_ly)\b/i;
function utcDayKey(date = new Date()) {
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, "0");
    const day = String(date.getUTCDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
}
function utcHourKey(date = new Date()) {
    return `${utcDayKey(date)}T${String(date.getUTCHours()).padStart(2, "0")}`;
}
function lastNDayKeys(days, from = new Date()) {
    const count = Math.max(1, Math.min(90, Math.floor(days)));
    const keys = [];
    const start = Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate());
    for (let i = count - 1; i >= 0; i -= 1) {
        keys.push(utcDayKey(new Date(start - i * 86_400_000)));
    }
    return keys;
}
function hashKey(raw) {
    return (0, node_crypto_1.createHash)("sha256").update(String(raw || "")).digest("hex").slice(0, 24);
}
function sanitizeVisitorId(raw) {
    return String(raw || "")
        .trim()
        .replace(/[^A-Za-z0-9_-]/g, "")
        .slice(0, 64);
}
function isLikelyBotUserAgent(userAgent) {
    const ua = String(userAgent || "").trim();
    if (!ua)
        return false;
    if (MOBILE_UA.test(ua))
        return false;
    return BOT_UA.test(ua);
}
exports.EMPTY_DAILY_COUNTS = {
    linkViews: 0,
    storeClicks: 0,
    attributions: 0,
    paywalls: 0,
    sales: 0,
    earningsCents: 0,
};
function emptyDailySeries(days) {
    const keys = lastNDayKeys(days);
    const zeros = keys.map(() => 0);
    return {
        days: keys,
        linkViews: [...zeros],
        storeClicks: [...zeros],
        attributions: [...zeros],
        paywalls: [...zeros],
        sales: [...zeros],
        earningsCents: [...zeros],
    };
}
//# sourceMappingURL=affiliateAnalytics.js.map