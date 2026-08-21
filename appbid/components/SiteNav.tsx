"use client";

import { BrandLogo } from "@/components/BrandLogo";
import { siteCopy, type Locale } from "@/lib/copy";

export function SiteNav({ locale }: { locale: Locale }) {
  const c = siteCopy(locale);
  return (
    <header className="site-nav-enter mx-auto flex w-full max-w-[1120px] items-center px-5 py-5 sm:py-6">
      <a href="/" className="group flex items-center gap-3 sm:gap-3.5">
        <BrandLogo size={56} priority className="site-brand-logo transition-transform duration-200 group-hover:scale-[1.03]" />
        <span className="text-[28px] font-extrabold tracking-[-0.03em] sm:text-[36px]">{c.brand}</span>
      </a>
    </header>
  );
}
