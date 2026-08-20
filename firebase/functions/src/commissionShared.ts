export const COMMISSION_RATE = Number(process.env.AFFILIATE_COMMISSION_RATE ?? "0.40");
export const COMMISSION_HOLD_DAYS = Number(process.env.AFFILIATE_HOLD_DAYS ?? "30");
export const COMMISSION_NET_FACTOR = Number(process.env.AFFILIATE_NET_FACTOR ?? "0.70");
export const LIFETIME_PRODUCT_ID = "com.useprocess.lifetime";

export type CommissionStatus = "pending_hold" | "payable" | "paid" | "clawed_back";

export function commissionFromRevenueCatEvent(event: any): {
  grossCents: number;
  netCents: number;
  commissionCents: number;
  commissionRate: number;
  currency: string;
  productId?: string;
} | null {
  const productId = String(event?.product_id ?? "").trim() || undefined;
  if (productId === LIFETIME_PRODUCT_ID) return null;

  const price = Number(event?.price_in_purchased_currency ?? event?.price);
  if (!Number.isFinite(price) || price <= 0) return null;

  const grossCents = Math.round(price * 100);
  const netCents = Math.round(grossCents * COMMISSION_NET_FACTOR);
  const commissionRate = COMMISSION_RATE;
  const commissionCents = Math.round(netCents * commissionRate);
  const currency =
    String(event?.currency ?? event?.currency_code ?? "EUR")
      .trim()
      .toUpperCase()
      .slice(0, 8) || "EUR";

  if (commissionCents <= 0) return null;

  return {
    grossCents,
    netCents,
    commissionCents,
    commissionRate,
    currency,
    productId,
  };
}

export function commissionDocId(ownerId: string, rcEventId: string): string {
  const safeEvent = String(rcEventId || "unknown")
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .slice(0, 120);
  return `${ownerId}_${safeEvent}`;
}
