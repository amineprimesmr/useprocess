const REVENUECAT_API = "https://api.revenuecat.com/v1";

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
}
