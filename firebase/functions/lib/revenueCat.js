"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isAnnualProduct = isAnnualProduct;
exports.isPaidPurchaseEvent = isPaidPurchaseEvent;
exports.fetchSubscriber = fetchSubscriber;
exports.activePremiumProductId = activePremiumProductId;
exports.hasActivePremium = hasActivePremium;
exports.hasPaidPremium = hasPaidPremium;
exports.grantPromotionalEntitlement = grantPromotionalEntitlement;
const REVENUECAT_API = "https://api.revenuecat.com/v1";
const ANNUAL_PRODUCT_IDS = new Set([
    "com.useprocess.annual",
    "com.useprocess.annual3499",
    "com.useprocess.annual4999",
]);
const LIFETIME_PRODUCT_ID = "com.useprocess.lifetime";
const UNPAID_PERIOD_TYPES = new Set(["trial", "promotional"]);
function isAnnualProduct(productId) {
    if (!productId)
        return false;
    return ANNUAL_PRODUCT_IDS.has(productId);
}
function isPaidPurchaseEvent(event) {
    const periodType = String(event?.period_type ?? "").toLowerCase();
    if (UNPAID_PERIOD_TYPES.has(periodType))
        return false;
    if (event?.is_trial_conversion === true)
        return true;
    const price = Number(event?.price ?? event?.price_in_purchased_currency);
    if (Number.isFinite(price) && price <= 0 && periodType === "trial") {
        return false;
    }
    return true;
}
async function fetchSubscriber(appUserId, secretKey) {
    const url = `${REVENUECAT_API}/subscribers/${encodeURIComponent(appUserId)}`;
    const response = await fetch(url, {
        method: "GET",
        headers: {
            Authorization: `Bearer ${secretKey}`,
            "Content-Type": "application/json",
        },
    });
    if (!response.ok) {
        const body = await response.text();
        throw new Error(`RC_FETCH_FAILED:${response.status}:${body}`);
    }
    return response.json();
}
function activePremiumProductId(subscriber, entitlementId) {
    const entitlement = subscriber?.subscriber?.entitlements?.[entitlementId];
    if (!entitlement)
        return undefined;
    const productId = entitlement.product_identifier;
    if (entitlement.expires_date) {
        const expiresAt = Date.parse(entitlement.expires_date);
        if (Number.isNaN(expiresAt) || expiresAt <= Date.now())
            return undefined;
    }
    return productId;
}
function hasActivePremium(subscriber, entitlementId) {
    return activePremiumProductId(subscriber, entitlementId) !== undefined;
}
/// Premium payé uniquement — ignore essai gratuit et entitlement promo.
function hasPaidPremium(subscriber, entitlementId) {
    const productId = activePremiumProductId(subscriber, entitlementId);
    if (!productId)
        return false;
    const root = subscriber?.subscriber ?? {};
    const subscription = root.subscriptions?.[productId];
    if (subscription) {
        const periodType = String(subscription.period_type ?? "").toLowerCase();
        if (UNPAID_PERIOD_TYPES.has(periodType))
            return false;
        return true;
    }
    const lifetimePurchases = root.non_subscriptions?.[productId]
        ?? root.non_subscriptions?.[LIFETIME_PRODUCT_ID];
    return Array.isArray(lifetimePurchases) && lifetimePurchases.length > 0;
}
async function grantPromotionalEntitlement(appUserId, entitlementId, duration, secretKey) {
    const url = `${REVENUECAT_API}/subscribers/${encodeURIComponent(appUserId)}/entitlements/${encodeURIComponent(entitlementId)}/promotional`;
    const response = await fetch(url, {
        method: "POST",
        headers: {
            Authorization: `Bearer ${secretKey}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({ duration }),
    });
    if (!response.ok) {
        const body = await response.text();
        throw new Error(`RC_GRANT_FAILED:${response.status}:${body}`);
    }
}
//# sourceMappingURL=revenueCat.js.map