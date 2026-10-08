import * as admin from "firebase-admin";

const REVENUECAT_API = "https://api.revenuecat.com/v1";

/**
 * MoneyMaker (RevenueCat replacement) speaks the same v1 API. During the migration, users on
 * older app versions still buy through RevenueCat and newer ones through MoneyMaker: reads merge
 * both, promotional grants go to both. Config lives server-only in billingConfiguration/moneymaker
 * ({ baseUrl, secretKey }); without it everything behaves exactly as before.
 */
let moneyMakerCache: { at: number; config: { baseUrl: string; secretKey: string } | null } | null = null;
async function moneyMakerConfig() {
  if (moneyMakerCache && Date.now() - moneyMakerCache.at < 300000) return moneyMakerCache.config;
  const data = (await admin.firestore().doc("billingConfiguration/moneymaker").get().catch(() => null))?.data();
  const config = data?.enabled !== false && typeof data?.secretKey === "string" && typeof data?.baseUrl === "string"
    ? { baseUrl: data.baseUrl.replace(/\/$/, ""), secretKey: data.secretKey } : null;
  moneyMakerCache = { at: Date.now(), config };
  return config;
}

async function fetchMoneyMakerSubscriber(appUserId: string): Promise<any | null> {
  const mm = await moneyMakerConfig();
  if (!mm) return null;
  try {
    const response = await fetch(`${mm.baseUrl}/v1/subscribers/${encodeURIComponent(appUserId)}`, {
      headers: { Authorization: `Bearer ${mm.secretKey}` }, signal: AbortSignal.timeout(8000),
    });
    return response.ok ? await response.json() : null;
  } catch {
    return null; // MoneyMaker unavailable: RevenueCat alone still answers.
  }
}

const laterDate = (a?: string | null, b?: string | null) => {
  if (a === null || b === null) return null; // lifetime wins
  return Date.parse(a ?? "0") >= Date.parse(b ?? "0") ? a : b;
};

/** Merges two v1 subscriber payloads; for each entitlement the one expiring last wins. Pure — unit-tested. */
export function mergeSubscribers(primary: any, secondary: any): any {
  if (!secondary?.subscriber) return primary;
  if (!primary?.subscriber) return secondary;
  const a = primary.subscriber, b = secondary.subscriber;
  const entitlements: Record<string, any> = { ...(a.entitlements ?? {}) };
  for (const [id, e] of Object.entries<any>(b.entitlements ?? {})) {
    const cur = entitlements[id];
    entitlements[id] = !cur || laterDate(e.expires_date, cur.expires_date) === e.expires_date ? e : cur;
  }
  const nonSubscriptions: Record<string, any[]> = { ...(a.non_subscriptions ?? {}) };
  for (const [id, list] of Object.entries<any[]>(b.non_subscriptions ?? {})) nonSubscriptions[id] = [...(nonSubscriptions[id] ?? []), ...list];
  return { ...primary, subscriber: { ...a, entitlements, subscriptions: { ...(b.subscriptions ?? {}), ...(a.subscriptions ?? {}) }, non_subscriptions: nonSubscriptions } };
}

export type RevenueCatDuration =
  | "daily"
  | "three_day"
  | "weekly"
  | "two_week"
  | "monthly"
  | "two_month"
  | "three_month"
  | "six_month"
  | "yearly"
  | "lifetime";

const ANNUAL_PRODUCT_IDS = new Set([
  "com.useprocess.annual",
  "com.useprocess.annual3499",
  "com.useprocess.annual3499trial",
  "com.useprocess.annual4999",
]);

const LIFETIME_PRODUCT_ID = "com.useprocess.lifetime";

const UNPAID_PERIOD_TYPES = new Set(["trial", "promotional"]);

export function isAnnualProduct(productId: string | undefined): boolean {
  if (!productId) return false;
  return ANNUAL_PRODUCT_IDS.has(productId);
}

export function isPaidPurchaseEvent(event: any): boolean {
  const periodType = String(event?.period_type ?? "").toLowerCase();
  if (UNPAID_PERIOD_TYPES.has(periodType)) return false;
  if (event?.is_trial_conversion === true) return true;

  const price = Number(event?.price ?? event?.price_in_purchased_currency);
  if (Number.isFinite(price) && price <= 0 && periodType === "trial") {
    return false;
  }
  return true;
}

/** A free trial starting: an INITIAL_PURCHASE whose period is the trial, not a payment. */
export function isTrialStartEvent(event: any): boolean {
  const eventType = String(event?.type ?? "").toUpperCase();
  const periodType = String(event?.period_type ?? "").toLowerCase();
  if (eventType !== "INITIAL_PURCHASE") return false;
  if (periodType !== "trial") return false;
  // A conversion is a payment, never a start, whatever the period says.
  return event?.is_trial_conversion !== true;
}

export async function fetchSubscriber(
  appUserId: string,
  secretKey: string
): Promise<any> {
  const mm = await moneyMakerConfig();
  const [revenueCat, moneyMaker] = await Promise.all([
    // Without MoneyMaker, a RevenueCat failure must surface exactly as before.
    fetchRevenueCatSubscriber(appUserId, secretKey).catch(error => { if (!mm) throw error; return null; }),
    mm ? fetchMoneyMakerSubscriber(appUserId) : Promise.resolve(null),
  ]);
  if (!revenueCat && !moneyMaker) throw new Error("SUBSCRIBER_FETCH_FAILED");
  return mergeSubscribers(revenueCat, moneyMaker);
}

async function fetchRevenueCatSubscriber(
  appUserId: string,
  secretKey: string
): Promise<any> {
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

export function activePremiumProductId(
  subscriber: any,
  entitlementId: string
): string | undefined {
  const entitlement = subscriber?.subscriber?.entitlements?.[entitlementId];
  if (!entitlement) return undefined;

  const productId = entitlement.product_identifier as string | undefined;
  if (entitlement.expires_date) {
    const expiresAt = Date.parse(entitlement.expires_date);
    if (Number.isNaN(expiresAt) || expiresAt <= Date.now()) return undefined;
  }

  return productId;
}

export function hasActivePremium(
  subscriber: any,
  entitlementId: string
): boolean {
  return activePremiumProductId(subscriber, entitlementId) !== undefined;
}

/// Premium payé uniquement — ignore essai gratuit et entitlement promo.
export function hasPaidPremium(
  subscriber: any,
  entitlementId: string
): boolean {
  const productId = activePremiumProductId(subscriber, entitlementId);
  if (!productId) return false;

  const root = subscriber?.subscriber ?? {};
  const subscription = root.subscriptions?.[productId];
  if (subscription) {
    const periodType = String(subscription.period_type ?? "").toLowerCase();
    if (UNPAID_PERIOD_TYPES.has(periodType)) return false;
    return true;
  }

  const lifetimePurchases = root.non_subscriptions?.[productId]
    ?? root.non_subscriptions?.[LIFETIME_PRODUCT_ID];
  return Array.isArray(lifetimePurchases) && lifetimePurchases.length > 0;
}

export async function grantPromotionalEntitlement(
  appUserId: string,
  entitlementId: string,
  duration: RevenueCatDuration,
  secretKey: string
): Promise<void> {
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
    if (!mmResponse?.ok) console.error("[grantPromotionalEntitlement] MoneyMaker mirror failed", mmResponse?.status);
  }
}
