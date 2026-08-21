import { applyPaidBid } from "@/lib/db";
import type { ListingKind } from "@/lib/types";
import type Stripe from "stripe";

export async function fulfillCheckoutSession(session: Stripe.Checkout.Session) {
  if (session.payment_status !== "paid" && session.payment_status !== "no_payment_required") {
    return null;
  }
  const meta = session.metadata ?? {};
  const listingKey = meta.listing_key;
  const url = meta.url;
  const targetBidCents = Number(meta.target_bid_cents);
  if (!listingKey || !url || !Number.isFinite(targetBidCents) || targetBidCents <= 0) {
    return null;
  }

  return applyPaidBid({
    sessionId: session.id,
    listingKey,
    url,
    title: meta.title || url,
    description: meta.description || "",
    icon: meta.icon || "",
    kind: (meta.kind as ListingKind) || "web",
    targetBidCents,
  });
}
