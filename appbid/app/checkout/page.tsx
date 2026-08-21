"use client";

import { BrandLogo } from "@/components/BrandLogo";
import { prefersEnglishFromNavigator, formatEuros } from "@/lib/format";
import { siteCopy, type Locale } from "@/lib/copy";
import { useEffect, useState } from "react";

export default function CheckoutPage() {
  const [locale, setLocale] = useState<Locale>("fr");
  const [error, setError] = useState("");
  const [amount, setAmount] = useState<number | null>(null);

  useEffect(() => {
    const loc: Locale = prefersEnglishFromNavigator() ? "en" : "fr";
    setLocale(loc);
    const q = new URLSearchParams(window.location.search);
    const url = q.get("url") ?? "";
    const requested = Number(q.get("amount") ?? "0");
    const rank = q.get("rank") ? Number(q.get("rank")) : undefined;
    setAmount(Number.isFinite(requested) ? requested : null);

    const run = async () => {
      const res = await fetch("/api/checkout", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          url,
          amount: requested,
          targetRank: rank,
          locale: loc,
        }),
      });
      const data = (await res.json().catch(() => ({}))) as {
        url?: string;
        error?: string;
        targetEuros?: number;
      };
      if (!res.ok || !data.url) {
        const copy = siteCopy(loc);
        const map: Record<string, string> = {
          INVALID: copy.invalidUrl,
          MIN_BID: copy.minBid,
          RAISE_ONLY: copy.raiseOnly,
        };
        setError(map[data.error ?? ""] || copy.checkoutError);
        return;
      }
      window.location.href = data.url;
    };

    run().catch(() => setError(siteCopy(loc).checkoutError));
  }, []);

  const copy = siteCopy(locale);

  return (
    <div className="grid min-h-screen place-items-center bg-[var(--bg)] px-5">
      <div className="rise w-full max-w-[420px] rounded-[28px] border border-[var(--line)] bg-[var(--card)] px-8 py-10 text-center shadow-[var(--shadow)]">
        <div className="logo-pulse mx-auto mb-6">
          <BrandLogo size={72} priority />
        </div>
        <p className="text-[13px] font-medium uppercase tracking-[0.18em] text-[var(--muted)]">Stripe · appmog</p>
        <h1 className="mt-2 text-[26px] font-extrabold tracking-tight">{copy.redirecting}</h1>
        {amount ? (
          <p className="mt-3 tabular text-[34px] font-extrabold text-[var(--ink)]">
            {formatEuros(amount, locale)}
          </p>
        ) : null}
        <p className="mt-4 text-[14px] leading-relaxed text-[var(--muted)]">
          {locale === "en"
            ? "Checkout opens with the minimum bid + $1 already filled so you take the spot immediately."
            : "Le paiement s'ouvre avec l'enchere minimum + 1 $ deja prefillée pour prendre la place tout de suite."}
        </p>
        {error ? (
          <div className="mt-6">
            <p className="text-[14px] text-[var(--ink)]">{error}</p>
            <a href="/" className="mt-4 inline-block text-[14px] font-medium underline">
              {copy.backHome}
            </a>
          </div>
        ) : null}
      </div>
    </div>
  );
}
