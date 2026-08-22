import { NextResponse } from "next/server";
import { getStripe } from "@/lib/stripe";
import { fulfillCheckoutSession } from "@/lib/fulfill";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  if (!process.env.STRIPE_SECRET_KEY) {
    return NextResponse.json({ error: "STRIPE_NOT_CONFIGURED" }, { status: 503 });
  }
  const id = new URL(request.url).searchParams.get("session_id") ?? "";
  if (!id.startsWith("cs_")) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }
  const session = await getStripe().checkout.sessions.retrieve(id);
  const result = await fulfillCheckoutSession(session);
  return NextResponse.json({
    paid: session.payment_status === "paid",
    rank: result?.rank ?? null,
    title: result?.title ?? session.metadata?.title ?? "",
    bidCents: result?.bidCents ?? Number(session.metadata?.target_bid_cents ?? 0),
  });
}
