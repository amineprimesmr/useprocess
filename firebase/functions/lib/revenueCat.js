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
exports.mergeSubscribers = mergeSubscribers;
exports.isAnnualProduct = isAnnualProduct;
exports.isPaidPurchaseEvent = isPaidPurchaseEvent;
exports.isTrialStartEvent = isTrialStartEvent;
exports.fetchSubscriber = fetchSubscriber;
exports.activePremiumProductId = activePremiumProductId;
exports.hasActivePremium = hasActivePremium;
exports.hasPaidPremium = hasPaidPremium;
exports.grantPromotionalEntitlement = grantPromotionalEntitlement;
const admin = __importStar(require("firebase-admin"));
const REVENUECAT_API = "https://api.revenuecat.com/v1";
/**
 * MoneyMaker (RevenueCat replacement) speaks the same v1 API. During the migration, users on
 * older app versions still buy through RevenueCat and newer ones through MoneyMaker: reads merge
 * both, promotional grants go to both. Config lives server-only in billingConfiguration/moneymaker
 * ({ baseUrl, secretKey }); without it everything behaves exactly as before.
 */
let moneyMakerCache = null;
async function moneyMakerConfig() {
    if (moneyMakerCache && Date.now() - moneyMakerCache.at < 300000)
        return moneyMakerCache.config;
    const data = (await admin.firestore().doc("billingConfiguration/moneymaker").get().catch(() => null))?.data();
    const config = data?.enabled !== false && typeof data?.secretKey === "string" && typeof data?.baseUrl === "string"
        ? { baseUrl: data.baseUrl.replace(/\/$/, ""), secretKey: data.secretKey } : null;
    moneyMakerCache = { at: Date.now(), config };
    return config;
}
async function fetchMoneyMakerSubscriber(appUserId) {
    const mm = await moneyMakerConfig();
    if (!mm)
        return null;
    try {
        const response = await fetch(`${mm.baseUrl}/v1/subscribers/${encodeURIComponent(appUserId)}`, {
            headers: { Authorization: `Bearer ${mm.secretKey}` }, signal: AbortSignal.timeout(8000),
        });
        return response.ok ? await response.json() : null;
    }
    catch {
        return null; // MoneyMaker unavailable: RevenueCat alone still answers.
    }
}
const laterDate = (a, b) => {
    if (a === null || b === null)
        return null; // lifetime wins
    return Date.parse(a ?? "0") >= Date.parse(b ?? "0") ? a : b;
};
/** Merges two v1 subscriber payloads; for each entitlement the one expiring last wins. Pure — unit-tested. */
function mergeSubscribers(primary, secondary) {
    if (!secondary?.subscriber)
        return primary;
    if (!primary?.subscriber)
        return secondary;
    const a = primary.subscriber, b = secondary.subscriber;
    const entitlements = { ...(a.entitlements ?? {}) };
    for (const [id, e] of Object.entries(b.entitlements ?? {})) {
        const cur = entitlements[id];
        entitlements[id] = !cur || laterDate(e.expires_date, cur.expires_date) === e.expires_date ? e : cur;
    }
    const nonSubscriptions = { ...(a.non_subscriptions ?? {}) };
    for (const [id, list] of Object.entries(b.non_subscriptions ?? {}))
        nonSubscriptions[id] = [...(nonSubscriptions[id] ?? []), ...list];
    return { ...primary, subscriber: { ...a, entitlements, subscriptions: { ...(b.subscriptions ?? {}), ...(a.subscriptions ?? {}) }, non_subscriptions: nonSubscriptions } };
}
const ANNUAL_PRODUCT_IDS = new Set([
    "com.useprocess.annual",
    "com.useprocess.annual3499",
    "com.useprocess.annual3499trial",
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
/** A free trial starting: an INITIAL_PURCHASE whose period is the trial, not a payment. */
function isTrialStartEvent(event) {
    const eventType = String(event?.type ?? "").toUpperCase();
    const periodType = String(event?.period_type ?? "").toLowerCase();
    if (eventType !== "INITIAL_PURCHASE")
        return false;
    if (periodType !== "trial")
        return false;
    // A conversion is a payment, never a start, whatever the period says.
    return event?.is_trial_conversion !== true;
}
async function fetchSubscriber(appUserId, secretKey) {
    const mm = await moneyMakerConfig();
    const [revenueCat, moneyMaker] = await Promise.all([
        // Without MoneyMaker, a RevenueCat failure must surface exactly as before.
        fetchRevenueCatSubscriber(appUserId, secretKey).catch(error => { if (!mm)
            throw error; return null; }),
        mm ? fetchMoneyMakerSubscriber(appUserId) : Promise.resolve(null),
    ]);
    if (!revenueCat && !moneyMaker)
        throw new Error("SUBSCRIBER_FETCH_FAILED");
    return mergeSubscribers(revenueCat, moneyMaker);
}
async function fetchRevenueCatSubscriber(appUserId, secretKey) {
    const url = `${REVENUECAT_API}/subscribers/${encodeURIComponent(appUserId)}`;
    const response = await fetch(url, {
        method: "GET",
        headers: {
            Authorization: `Bearer ${secretKey}`,
            "Content-Type": "application/json",
        },
        signal: AbortSignal.timeout(10000),
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
    // Mirror the grant in MoneyMaker so app versions reading MoneyMaker unlock it too.
    const mm = await moneyMakerConfig();
    if (mm) {
        const mmResponse = await fetch(`${mm.baseUrl}/v1/subscribers/${encodeURIComponent(appUserId)}/entitlements/${encodeURIComponent(entitlementId)}/promotional`, {
            method: "POST", headers: { Authorization: `Bearer ${mm.secretKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({ duration }), signal: AbortSignal.timeout(10000),
        }).catch(() => null);
        if (!mmResponse?.ok)
            console.error("[grantPromotionalEntitlement] MoneyMaker mirror failed", mmResponse?.status);
    }
}
//# sourceMappingURL=revenueCat.js.map