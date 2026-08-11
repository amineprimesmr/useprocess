"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isAnnualProduct = isAnnualProduct;
exports.fetchSubscriber = fetchSubscriber;
exports.activePremiumProductId = activePremiumProductId;
exports.hasActivePremium = hasActivePremium;
exports.grantPromotionalEntitlement = grantPromotionalEntitlement;
const REVENUECAT_API = "https://api.revenuecat.com/v1";
const ANNUAL_PRODUCT_IDS = new Set([
    "com.useprocess.annual",
    "com.useprocess.annual3499",
    "com.useprocess.annual4999",
]);
function isAnnualProduct(productId) {
    if (!productId)
        return false;
    return ANNUAL_PRODUCT_IDS.has(productId);
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
    if (!entitlement?.expires_date)
        return undefined;
    const expiresAt = Date.parse(entitlement.expires_date);
    if (Number.isNaN(expiresAt) || expiresAt <= Date.now())
        return undefined;
    return entitlement.product_identifier;
}
function hasActivePremium(subscriber, entitlementId) {
    return activePremiumProductId(subscriber, entitlementId) !== undefined;
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