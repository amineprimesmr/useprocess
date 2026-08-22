import { NextResponse } from "next/server";
import { findListingByKey, resolveClaimAmount } from "@/lib/db";
import { normalizeTarget } from "@/lib/keys";
import { resolveMeta } from "@/lib/meta";
import { centsToDollars } from "@/lib/format";
import { getStripe, integrationIdentifier, siteUrl } from "@/lib/stripe";

export const dynamic = "force-dynamic";

type CheckoutBody = {
  url?: string;
  amount?: number;
  targetRank?: number;
  locale?: "fr" | "en";
};

export async function POST(request: Request) {
  if (!process.env.STRIPE_SECRET_KEY) {
    return NextResponse.json({ error: "STRIPE_NOT_CONFIGURED" }, { status: 503 });
  }

  const body = (await request.json().catch(() => ({}))) as CheckoutBody;
  const target = normalizeTarget(body.url ?? "");
  if (!target) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }

  try {
    const quote = await resolveClaimAmount({
      listingKey: target.key,
      requestedEuros: Number(body.amount),
      targetRank: body.targetRank,
    });

    const existing = await findListingByKey(target.key);
    const locale = body.locale === "en" ? "en" : "fr";
    const meta = await resolveMeta(target, locale);
    const title = meta.title || String(existing?.title ?? target.url);
    const description = meta.description || String(existing?.description ?? "");
    const icon = meta.icon || String(existing?.icon ?? "");
    const origin = siteUrl();
    const chargeEuros = centsToDollars(quote.chargeCents);
    const targetEuros = centsToDollars(quote.targetBidCents);

    const stripe = getStripe();
    const bidLine =
      locale === "en"
        ? `Public leaderboard bid — $${targetEuros} (rank is the bid)`
        : `Enchère classement public — ${targetEuros} $ (le rang, c'est l'enchère)`;

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      managed_payments: { enabled: false },
      locale: locale === "fr" ? "fr" : "en",
      success_url: `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/?canceled=1`,
      customer_creation: "if_required",
      billing_address_collection: "auto",
      allow_promotion_codes: false,
      custom_text: {
        submit: {
          message:
            locale === "en"
              ? "Rank is the bid — nothing else. If someone outbids you before this payment lands, you still join the board at whatever rank this amount can take. Bids are not refunded."
              : "Le rang, c'est l'enchere — rien d'autre. Si quelqu'un surencherit avant que ce paiement soit confirme, tu restes sur le classement au rang que ce montant peut prendre. Les encheres ne sont pas remboursees.",
        },
        after_submit: {
          message:
            locale === "en"
              ? "You can raise later with the same App Store link — pay the full new bid amount."
              : "Tu pourras monter plus tard avec le même lien App Store — paie le montant d'enchère en entier.",
        },
      },
      metadata: {
        listing_key: target.key,
        url: target.url,
        kind: target.kind,
        title,
        description: description.slice(0, 450),
        icon: icon.slice(0, 500),
        target_bid_cents: String(quote.targetBidCents),
        charge_cents: String(quote.chargeCents),
        current_bid_cents: String(quote.currentBidCents),
      },
      payment_intent_data: {
        metadata: {
          listing_key: target.key,
          target_bid_cents: String(quote.targetBidCents),
        },
        description: `appmog · ${title} · $${targetEuros}`,
      },
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: "usd",
            unit_amount: quote.chargeCents,
            product_data: {
              name: locale === "en" ? `appmog rank · ${title}` : `Rang appmog · ${title}`,
              description: bidLine,
              images: icon.startsWith("https://") ? [icon] : undefined,
            },
          },
        },
      ],
      integration_identifier: integrationIdentifier(),
    });

    if (!session.url) {
      return NextResponse.json({ error: "NO_CHECKOUT_URL" }, { status: 500 });
    }

    return NextResponse.json({
      url: session.url,
      chargeEuros,
      targetEuros,
    });
  } catch (error) {
    const code = error instanceof Error ? error.message : "ERROR";
    if (code === "MIN_BID") return NextResponse.json({ error: "MIN_BID" }, { status: 400 });
    if (code === "MAX_BID") return NextResponse.json({ error: "MAX_BID" }, { status: 400 });
    if (code === "RAISE_ONLY") return NextResponse.json({ error: "RAISE_ONLY" }, { status: 400 });
    console.error("checkout failed", error instanceof Error ? error.message : error);
    return NextResponse.json({ error: "CHECKOUT_FAILED" }, { status: 500 });
  }
}
