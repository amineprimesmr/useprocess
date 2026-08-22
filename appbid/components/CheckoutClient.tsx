"use client";

import { createCheckoutSession, redirectToCheckout } from "@/lib/checkout-client";
import { siteCopy, type Locale } from "@/lib/copy";
import { useEffect, useRef } from "react";

export function CheckoutClient({ locale }: { locale: Locale }) {
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;

    const q = new URLSearchParams(window.location.search);
    const url = q.get("url") ?? "";
    const amount = Number(q.get("amount") ?? "0");
    const rank = q.get("rank") ? Number(q.get("rank")) : undefined;
    const loc: Locale = q.get("locale") === "en" ? "en" : locale;

    if (!url) {
      window.location.replace("/");
      return;
    }

    createCheckoutSession({ url, amount, targetRank: rank, locale: loc })
      .then((result) => {
        if (result.ok) {
          redirectToCheckout(result.stripeUrl);
          return;
        }
        window.location.replace(`/?checkout_error=${encodeURIComponent(result.error)}`);
      })
      .catch(() => window.location.replace("/?checkout_error=CHECKOUT_FAILED"));
  }, [locale]);

  return null;
}
