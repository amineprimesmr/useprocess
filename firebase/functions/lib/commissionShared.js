"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LIFETIME_PRODUCT_ID = exports.COMMISSION_NET_FACTOR = exports.COMMISSION_HOLD_DAYS = exports.COMMISSION_RATE = void 0;
exports.commissionFromRevenueCatEvent = commissionFromRevenueCatEvent;
exports.commissionDocId = commissionDocId;
exports.COMMISSION_RATE = Number(process.env.AFFILIATE_COMMISSION_RATE ?? "0.40");
exports.COMMISSION_HOLD_DAYS = Number(process.env.AFFILIATE_HOLD_DAYS ?? "30");
exports.COMMISSION_NET_FACTOR = Number(process.env.AFFILIATE_NET_FACTOR ?? "0.70");
exports.LIFETIME_PRODUCT_ID = "com.useprocess.lifetime";
function commissionFromRevenueCatEvent(event) {
    const productId = String(event?.product_id ?? "").trim() || undefined;
    if (productId === exports.LIFETIME_PRODUCT_ID)
        return null;
    const price = Number(event?.price_in_purchased_currency ?? event?.price);
    if (!Number.isFinite(price) || price <= 0)
        return null;
    const grossCents = Math.round(price * 100);
    const netCents = Math.round(grossCents * exports.COMMISSION_NET_FACTOR);
    const commissionRate = exports.COMMISSION_RATE;
    const commissionCents = Math.round(netCents * commissionRate);
    const currency = String(event?.currency ?? event?.currency_code ?? "EUR")
        .trim()
        .toUpperCase()
        .slice(0, 8) || "EUR";
    if (commissionCents <= 0)
        return null;
    return {
        grossCents,
        netCents,
        commissionCents,
        commissionRate,
        currency,
        productId,
    };
}
function commissionDocId(ownerId, rcEventId) {
    const safeEvent = String(rcEventId || "unknown")
        .replace(/[^a-zA-Z0-9_-]/g, "_")
        .slice(0, 120);
    return `${ownerId}_${safeEvent}`;
}
//# sourceMappingURL=commissionShared.js.map