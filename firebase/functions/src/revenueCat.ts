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

export function isAnnualProduct(productId: string | undefined): boolean {
  if (!productId) return false;
  return ANNUAL_PRODUCT_IDS.has(productId);
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
  if (!entitlement?.expires_date) return undefined;

  const expiresAt = Date.parse(entitlement.expires_date);
  if (Number.isNaN(expiresAt) || expiresAt <= Date.now()) return undefined;

  return entitlement.product_identifier as string | undefined;
}

export function hasActivePremium(
  subscriber: any,
  entitlementId: string
): boolean {
  return activePremiumProductId(subscriber, entitlementId) !== undefined;
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
