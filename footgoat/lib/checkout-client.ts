import type { Locale } from "@/lib/copy";

export type CheckoutParams = {
  url: string;
  amount: number;
  nickname: string;
  targetRank?: number;
  locale: Locale;
};

export type CheckoutError =
  | "INVALID"
  | "NEED_NICK"
  | "MIN_BID"
  | "MAX_BID"
  | "RAISE_ONLY"
  | "CHECKOUT_FAILED"
  | "STRIPE_NOT_CONFIGURED"
  | "NO_CHECKOUT_URL";

export type CheckoutResult =
  | { ok: true; stripeUrl: string }
  | { ok: false; error: CheckoutError };

export async function createCheckoutSession(params: CheckoutParams): Promise<CheckoutResult> {
  const res = await fetch("/api/checkout", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(params),
  });
  const data = (await res.json().catch(() => ({}))) as { url?: string; error?: string };
  if (!res.ok || !data.url) {
    const known = new Set<CheckoutError>([
      "INVALID",
      "NEED_NICK",
      "MIN_BID",
      "MAX_BID",
      "RAISE_ONLY",
      "CHECKOUT_FAILED",
      "STRIPE_NOT_CONFIGURED",
      "NO_CHECKOUT_URL",
    ]);
    const error = known.has(data.error as CheckoutError) ? (data.error as CheckoutError) : "CHECKOUT_FAILED";
    return { ok: false, error };
  }
  return { ok: true, stripeUrl: data.url };
}

export function redirectToCheckout(stripeUrl: string) {
  window.location.assign(stripeUrl);
}
