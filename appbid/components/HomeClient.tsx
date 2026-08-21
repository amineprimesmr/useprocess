"use client";

import Image from "next/image";
import { AnimatedAmount } from "@/components/AnimatedAmount";
import { AppAvatar } from "@/components/AppAvatar";
import { BrandLogo } from "@/components/BrandLogo";
import { HeroSpotlight } from "@/components/HeroSpotlight";
import { SiteNav } from "@/components/SiteNav";
import { StatsPill } from "@/components/StatsPill";
import { siteCopy, type Locale } from "@/lib/copy";
import {
  MIN_BID_USD,
  centsToDollars,
  formatCompactCount,
  formatMoney,
  prefersEnglishFromNavigator,
  relativeTime,
} from "@/lib/format";
import type { BoardPayload, Listing } from "@/lib/types";
import { useLiveBoard } from "@/hooks/useLiveBoard";
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";

export function HomeClient({ initial }: { initial: BoardPayload }) {
  const [locale, setLocale] = useState<Locale>("fr");
  const board = useLiveBoard(initial);
  const [url, setUrl] = useState("");
  const [amount, setAmount] = useState(initial.claimOneEuros);
  const [amountTouched, setAmountTouched] = useState(false);
  const [hoverRank, setHoverRank] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [heroReady, setHeroReady] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const listingFlash = useRef<Map<string, number>>(new Map());
  const [flashIds, setFlashIds] = useState<string[]>([]);

  const copy = siteCopy(locale);
  const leader = board.listings[0] ?? null;

  useEffect(() => {
    setLocale(prefersEnglishFromNavigator() ? "en" : "fr");
    setHeroReady(true);
  }, []);

  useEffect(() => {
    const ids: string[] = [];
    for (const listing of board.listings) {
      const sig = listing.updatedAt * 1000 + listing.bidCents + listing.rank;
      const prev = listingFlash.current.get(listing.id);
      if (prev !== undefined && prev !== sig) ids.push(listing.id);
      listingFlash.current.set(listing.id, sig);
    }
    if (!ids.length) return;
    setFlashIds(ids);
    const t = window.setTimeout(() => setFlashIds([]), 700);
    return () => window.clearTimeout(t);
  }, [board.listings, board.revision]);

  useEffect(() => {
    if (!amountTouched) setAmount(board.claimOneEuros);
  }, [board.claimOneEuros, amountTouched]);

  const startCheckout = (opts: { amount: number; targetRank?: number }) => {
    const value = url.trim();
    if (!value) {
      setError(copy.needUrl);
      inputRef.current?.focus();
      inputRef.current?.classList.add("input-shake");
      window.setTimeout(() => inputRef.current?.classList.remove("input-shake"), 420);
      return;
    }
    setBusy(true);
    setError("");
    const q = new URLSearchParams({ url: value, amount: String(opts.amount), locale });
    if (opts.targetRank) q.set("rank", String(opts.targetRank));
    window.location.href = `/checkout?${q.toString()}`;
  };

  return (
    <div className={`min-h-screen pb-16 ${heroReady ? "hero-ready" : ""}`}>
      <SiteNav locale={locale} />

      <main className="mx-auto w-full max-w-[760px] px-5">
        <StatsPill
          online={board.online}
          visitors={board.visitors}
          locale={locale}
          onlineLabel={copy.online}
          visitorsLabel={copy.visitorsSince}
        />

        <h1 className="hero-title mt-8 text-center text-[34px] font-extrabold leading-[1.08] tracking-[-0.04em] sm:text-[50px]">
          {copy.claimFor}{" "}
          <AmountStepper
            amount={amount}
            min={MIN_BID_USD}
            locale={locale}
            onChange={(next) => {
              setAmountTouched(true);
              setAmount(next);
            }}
          />
        </h1>

        <p className="hero-hint mx-auto mt-4 max-w-[480px] text-center text-[15px] leading-relaxed text-[var(--muted)]">{copy.heroHint}</p>

        <form
          className="hero-form mx-auto mt-7 flex max-w-[560px] flex-col gap-3 sm:flex-row sm:items-center"
          onSubmit={(e) => { e.preventDefault(); startCheckout({ amount }); }}
        >
          <label className="flex min-h-[56px] flex-1 items-center gap-3 rounded-full border border-[var(--line)] bg-[var(--card)] px-5 shadow-[var(--shadow)] focus-within:border-[rgba(0,0,0,0.22)]">
            <AppStoreInputIcon />
            <input
              ref={inputRef}
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder={copy.placeholder}
              className="w-full bg-transparent text-[15px] outline-none placeholder:text-[var(--muted)]"
              autoCapitalize="off"
              autoCorrect="off"
              spellCheck={false}
            />
          </label>
          <button type="submit" disabled={busy} className="cta-outbid min-h-[56px] rounded-full px-8 text-[16px] font-semibold active:scale-[0.98] disabled:opacity-60">
            {copy.outbid}
          </button>
        </form>
        <p className="hero-sub mt-3 text-center text-[13px] text-[var(--muted)]">{copy.alreadyOn}</p>
        {error ? <p className="mt-2 text-center text-[13px] text-[var(--ink)]">{error}</p> : null}

        {leader ? (
          <HeroSpotlight listing={leader} locale={locale} claimAmount={amount} onClaim={() => startCheckout({ amount, targetRank: 1 })} />
        ) : null}
      </main>

      <section id="board" className="board-section mx-auto mt-8 w-full max-w-[920px] px-5">
        {board.listings.length > 0 ? (
          <p className="board-live-label mb-4 flex items-center justify-center gap-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">
            <span className="live-dot-bright h-2 w-2 rounded-full" />
            {locale === "fr" ? "Classement live" : "Live leaderboard"}
          </p>
        ) : null}
        {board.listings.length === 0 ? (
          <div className="rounded-[24px] border border-[var(--line)] bg-[var(--card)] px-8 py-14 text-center shadow-[var(--shadow)]">
            <BrandLogo size={64} className="mx-auto" />
            <p className="mt-5 text-xl font-semibold">{copy.emptyTitle}</p>
            <p className="mt-2 text-[var(--muted)]">{copy.emptyBody}</p>
          </div>
        ) : (
          board.listings.map((listing, index) => (
            <div key={listing.id}>
              {index === 3 ? <Divider label={copy.top3} /> : null}
              {index === 10 ? <Divider label={copy.top10} /> : null}
              <RankCard
                listing={listing}
                locale={locale}
                copy={copy}
                index={index}
                flash={flashIds.includes(listing.id)}
                hovered={hoverRank === listing.rank}
                onHover={setHoverRank}
                onClaim={() => startCheckout({ amount: centsToDollars(listing.bidCents) + 1, targetRank: listing.rank })}
              />
            </div>
          ))
        )}
      </section>

      <footer className="mx-auto mt-12 max-w-[760px] px-5 pb-6 text-center text-[14px] text-[var(--muted)]">
        <p>
          {copy.made}{" "}
          <span className="text-[24px] font-extrabold text-[var(--ink)]">{formatMoney(board.revenueEuros, locale)}</span>
        </p>
        <p className="mt-1">{copy.sinceLaunch} {relativeLaunch(board.launchedAt, locale)}</p>
      </footer>
    </div>
  );
}

function relativeLaunch(ts: number, locale: Locale): string {
  const hours = Math.max(1, Math.round((Date.now() - ts) / 36e5));
  if (hours < 24) return locale === "fr" ? `${hours} h` : `${hours}h`;
  return locale === "fr" ? `${Math.round(hours / 24)} j` : `${Math.round(hours / 24)}d`;
}

function AmountStepper({
  amount,
  min,
  locale,
  onChange,
}: {
  amount: number;
  min: number;
  locale: Locale;
  onChange: (value: number) => void;
}) {
  const holdTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const holdInterval = useRef<ReturnType<typeof setInterval> | null>(null);
  const amountRef = useRef(amount);
  amountRef.current = amount;

  const clearHold = () => {
    if (holdTimer.current) {
      clearTimeout(holdTimer.current);
      holdTimer.current = null;
    }
    if (holdInterval.current) {
      clearInterval(holdInterval.current);
      holdInterval.current = null;
    }
  };

  useEffect(() => clearHold, []);

  const step = (delta: number) => {
    onChange(Math.max(min, amountRef.current + delta));
  };

  const startHold = (delta: number) => {
    step(delta);
    holdTimer.current = setTimeout(() => {
      holdInterval.current = setInterval(() => step(delta), 90);
    }, 320);
  };

  return (
    <span className="amount-stepper mt-2 inline-flex items-center justify-center gap-2.5 sm:mt-0" role="group" aria-label={locale === "fr" ? "Montant" : "Amount"}>
      <StepperButton
        label={locale === "fr" ? "Diminuer" : "Decrease"}
        disabled={amount <= min}
        onPress={() => startHold(-1)}
        onRelease={clearHold}
      >
        <MinusIcon />
      </StepperButton>
      <span className="amount-stepper-display">
        <AnimatedAmount
          value={amount}
          locale={locale}
          className="text-[34px] font-extrabold text-[var(--ink)] sm:text-[44px]"
          duration={360}
        />
      </span>
      <StepperButton
        label={locale === "fr" ? "Augmenter" : "Increase"}
        disabled={false}
        onPress={() => startHold(1)}
        onRelease={clearHold}
      >
        <PlusIcon />
      </StepperButton>
    </span>
  );
}

function StepperButton({
  label,
  disabled,
  onPress,
  onRelease,
  children,
}: {
  label: string;
  disabled: boolean;
  onPress: () => void;
  onRelease: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      disabled={disabled}
      className="stepper-btn"
      onPointerDown={(e) => {
        if (disabled) return;
        e.preventDefault();
        (e.currentTarget as HTMLButtonElement).setPointerCapture(e.pointerId);
        onPress();
      }}
      onPointerUp={onRelease}
      onPointerCancel={onRelease}
      onClick={(e) => e.preventDefault()}
    >
      {children}
    </button>
  );
}

function MinusIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 12h14" />
    </svg>
  );
}

function PlusIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 5v14M5 12h14" />
    </svg>
  );
}

function AppStoreInputIcon() {
  return (
    <Image
      src="/appstore-badge.png"
      alt=""
      width={24}
      height={24}
      className="shrink-0 rounded-[6px]"
      priority
    />
  );
}

function Divider({ label }: { label: string }) {
  return (
    <div className="my-5 flex items-center gap-3">
      <div className="h-px flex-1 bg-[var(--line)]" />
      <span className="rounded-full border border-[var(--line)] px-3 py-0.5 text-[10px] font-semibold tracking-[0.14em] text-[var(--muted)]">{label}</span>
      <div className="h-px flex-1 bg-[var(--line)]" />
    </div>
  );
}

function RankCard({
  listing,
  locale,
  copy,
  index,
  flash,
  hovered,
  onHover,
  onClaim,
}: {
  listing: Listing;
  locale: Locale;
  copy: ReturnType<typeof siteCopy>;
  index: number;
  flash: boolean;
  hovered: boolean;
  onHover: (rank: number | null) => void;
  onClaim: () => void;
}) {
  const claim = centsToDollars(listing.bidCents) + 1;
  const featured = listing.rank === 1;
  const animate = index < 6;

  return (
    <article
      className={`rank-card relative mb-3 overflow-hidden rounded-[24px] border px-5 py-4 sm:pb-6 ${featured ? "rank-card-featured" : ""} ${animate ? "rank-reveal" : ""} ${flash ? "rank-card-flash" : ""}`}
      style={
        {
          "--reveal-delay": `${index * 60}ms`,
          background: featured ? "var(--accent-soft)" : "var(--card)",
          borderColor: featured ? "rgba(0,0,0,0.14)" : "var(--line)",
          boxShadow: "var(--shadow)",
        } as CSSProperties
      }
      onMouseEnter={() => onHover(listing.rank)}
      onMouseLeave={() => onHover(null)}
    >
      <div className="flex items-start gap-4">
        <span className="mt-1 grid h-8 w-8 shrink-0 place-items-center rounded-full text-[12px] font-semibold" style={{ background: listing.rank <= 3 ? "var(--accent-mid)" : "rgba(0,0,0,0.06)", color: listing.rank <= 3 ? "var(--ink)" : "var(--muted)" }}>
          #{listing.rank}
        </span>
        <AppAvatar title={listing.title} icon={listing.icon} listingKey={listing.listingKey} size={72} />
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-3">
            <a href={`/go/${listing.id}`} className="truncate text-[18px] font-bold hover:opacity-70">{listing.title}</a>
            <p className={`rank-bid tabular shrink-0 text-[20px] font-extrabold text-[var(--ink)] ${flash ? "rank-bid-flash" : ""}`}>
              {formatMoney(centsToDollars(listing.bidCents), locale)}
            </p>
          </div>
          {listing.description ? <p className="mt-1 line-clamp-2 text-[14px] text-[var(--muted)]">{listing.description}</p> : null}
          <p className="mt-2 text-[12px] text-[var(--muted)]">
            {relativeTime(listing.updatedAt, locale)} · {formatCompactCount(listing.clicks, locale)} {copy.clicks}
          </p>
          <button type="button" onClick={onClaim} className="btn-primary mt-3 rounded-full px-4 py-2 text-[13px] font-semibold sm:hidden">
            {copy.claimRank} {formatMoney(claim, locale)}
          </button>
        </div>
      </div>
      {hovered ? (
        <button type="button" onClick={onClaim} className="claim-pill btn-primary absolute bottom-3 left-1/2 hidden rounded-full px-5 py-2 text-[14px] font-semibold sm:block">
          {copy.claimRank} {formatMoney(claim, locale)}
        </button>
      ) : null}
    </article>
  );
}
