import { NextResponse } from "next/server";
import { getStripe } from "@/lib/stripe";
import { fulfillCheckoutSession } from "@/lib/fulfill";
import type Stripe from "stripe";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(request: Request) {
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secret || !process.env.STRIPE_SECRET_KEY) {
    return NextResponse.json({ error: "WEBHOOK_NOT_CONFIGURED" }, { status: 503 });
  }

  const signature = request.headers.get("stripe-signature");
  if (!signature) {
    return NextResponse.json({ error: "NO_SIGNATURE" }, { status: 400 });
  }

  const raw = await request.text();
  let event: Stripe.Event;
  try {
    event = getStripe().webhooks.constructEvent(raw, signature, secret);
  } catch {
    return NextResponse.json({ error: "INVALID_SIGNATURE" }, { status: 400 });
  }

  if (
    event.type === "checkout.session.completed" ||
    event.type === "checkout.session.async_payment_succeeded"
  ) {
    try {
      const result = await fulfillCheckoutSession(event.data.object as Stripe.Checkout.Session);
      if (!result) {
        console.error("webhook fulfill skipped", event.id, (event.data.object as Stripe.Checkout.Session).id);
      }
    } catch (error) {
      console.error("webhook fulfill failed", event.id, error);
      return NextResponse.json({ error: "FULFILL_FAILED" }, { status: 500 });
    }
  }

  return NextResponse.json({ received: true });
}
