"use client";

import { AppAvatar } from "@/components/AppAvatar";
import { BrandLogo } from "@/components/BrandLogo";
import { siteCopy, type Locale } from "@/lib/copy";
import type { Listing } from "@/lib/types";

export function SiteNav({ locale, leader }: { locale: Locale; leader?: Listing | null }) {
  const c = siteCopy(locale);

  return (
    <header className="site-nav-enter mx-auto flex w-full max-w-[1120px] items-center justify-between gap-4 px-5 py-5 sm:py-6">
      <a href="/" className="group flex min-w-0 items-center gap-3 sm:gap-3.5">
        <BrandLogo size={56} priority className="site-brand-logo transition-transform duration-200 group-hover:scale-[1.03]" />
        <span className="truncate text-[28px] font-extrabold tracking-[-0.03em] sm:text-[36px]">{c.brand}</span>
      </a>

      {leader ? (
        <a
          href={`/go/${leader.id}`}
          className="nav-leader group relative shrink-0"
          title={leader.title}
          aria-label={c.navLeader(leader.title)}
        >
          <AppAvatar
            title={leader.title}
            icon={leader.icon}
            listingKey={leader.listingKey}
            size={48}
            className="nav-leader-icon transition-transform duration-200 group-hover:scale-[1.04]"
          />
          <span className="nav-leader-rank">#1</span>
          <span className="nav-leader-live" aria-hidden="true" />
        </a>
      ) : null}
    </header>
  );
}
