"use client";

import { AppAvatar } from "@/components/AppAvatar";
import { AnimatedAmount } from "@/components/AnimatedAmount";
import { siteCopy, type Locale } from "@/lib/copy";
import { centsToDollars, formatMoney } from "@/lib/format";
import type { Listing } from "@/lib/types";

type Props = {
  listing: Listing;
  locale: Locale;
  claimAmount: number;
  onClaim: () => void;
};

export function HeroSpotlight({ listing, locale, claimAmount, onClaim }: Props) {
  const copy = siteCopy(locale);
  const current = centsToDollars(listing.bidCents);

  return (
    <div className="hero-spotlight mx-auto mt-8 max-w-[560px]">
      <article className="spotlight-card rounded-[24px] border px-5 py-4 sm:px-6">
        <div className="flex items-center gap-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[var(--accent-mid)] text-[13px] font-bold text-[var(--ink)]">
            #1
          </span>
          <AppAvatar title={listing.title} icon={listing.icon} listingKey={listing.listingKey} size={52} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-[17px] font-bold">{listing.title}</p>
            <p className="mt-0.5 text-[13px] text-[var(--muted)]">
              {formatMoney(current, locale)} ·{" "}
              <span className="font-semibold text-[var(--ink)]">
                +{formatMoney(1, locale)} → {formatMoney(claimAmount, locale)}
              </span>
            </p>
          </div>
        </div>
        <button type="button" onClick={onClaim} className="cta-outbid mt-4 flex w-full items-center justify-center gap-2 rounded-full px-5 py-3 text-[15px] font-semibold sm:hidden">
          {copy.outbid} · <AnimatedAmount value={claimAmount} locale={locale} duration={500} />
        </button>
      </article>
      <a href="#board" className="mt-4 block text-center text-[12px] text-[var(--muted)] hover:text-[var(--ink)]">
        {locale === "fr" ? "Voir le classement ↓" : "See leaderboard ↓"}
      </a>
    </div>
  );
}
