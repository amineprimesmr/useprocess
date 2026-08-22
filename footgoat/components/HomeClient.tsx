"use client";

import { AppStoreUrlField, type UrlFieldError } from "@/components/AppStoreUrlField";
import { AnimatedAmount } from "@/components/AnimatedAmount";
import { AppAvatar } from "@/components/AppAvatar";
import { BrandLogo } from "@/components/BrandLogo";
import { HeroSpotlight } from "@/components/HeroSpotlight";
import { OwnerPreview } from "@/components/OwnerPreview";
import { SiteNav } from "@/components/SiteNav";
import { StatsPill } from "@/components/StatsPill";
import { siteCopy, type Locale } from "@/lib/copy";
import {
  MAX_BID_USD,
  centsToDollars,
  formatCompactCount,
  formatMoney,
  parseBidInput,
  relativeTime,
} from "@/lib/format";
import type { BoardPayload, Listing } from "@/lib/types";
import { normalizeTarget } from "@/lib/keys";
import { parseNickname } from "@/lib/nickname";
import { matchPlayer } from "@/lib/player-search";
import { createCheckoutSession, redirectToCheckout } from "@/lib/checkout-client";
import { useLiveBoard } from "@/hooks/useLiveBoard";
import { useLocale } from "@/hooks/useLocale";
import { quoteBid } from "@/lib/bid-quote";
import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";

export function HomeClient({ initial, locale: initialLocale }: { initial: BoardPayload; locale: Locale }) {
  const locale = useLocale(initialLocale);
  const board = useLiveBoard(initial);
  const [url, setUrl] = useState("");
  const [nickname, setNickname] = useState("");
  const [nickError, setNickError] = useState(false);
  const [amount, setAmount] = useState(initial.claimOneEuros);
  const [amountTouched, setAmountTouched] = useState(false);
  const [hoverRank, setHoverRank] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [urlError, setUrlError] = useState<UrlFieldError | null>(null);
  const [error, setError] = useState("");
  const [heroReady, setHeroReady] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const nickRef = useRef<HTMLInputElement>(null);
  const formRef = useRef<HTMLFormElement>(null);
  const listingFlash = useRef<Map<string, number>>(new Map());
  const [flashIds, setFlashIds] = useState<string[]>([]);

  const copy = siteCopy(locale);
  const leader = board.listings[0] ?? null;

  const urlTarget = useMemo(() => normalizeTarget(url.trim()), [url]);
  const matchedListing = useMemo(() => matchPlayer(board.listings, url), [board.listings, url]);
  const bidQuote = useMemo(
    () =>
      quoteBid({
        listings: board.listings,
        listingKey: matchedListing?.listingKey ?? urlTarget?.key ?? null,
        targetEuros: amount,
        minTargetEuros: board.claimOneEuros,
      }),
    [board.listings, board.claimOneEuros, amount, matchedListing, urlTarget],
  );

  const heroHint = bidQuote.isExisting ? (
    <>
      {copy.alreadyOnBoardAt(formatMoney(bidQuote.currentEuros, locale))}{" "}
      {bidQuote.canRaise
        ? copy.checkoutFullBid(formatMoney(bidQuote.targetEuros, locale))
        : copy.raiseOnly}
    </>
  ) : (
    copy.heroHint
  );
  const submitLabel = copy.outbid;
  const submitDisabled = busy || (bidQuote.isExisting && !bidQuote.canRaise);

  useEffect(() => {
    setHeroReady(true);
    const saved = window.localStorage.getItem("footgoat.nick");
    if (saved && parseNickname(saved)) setNickname(saved);
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

  const nudgeUrlInput = (kind: UrlFieldError) => {
    setUrlError(kind);
    setError("");
    formRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    window.setTimeout(() => inputRef.current?.focus({ preventScroll: true }), 280);
  };

  const selectPlayer = (listing: Listing) => {
    setUrl(listing.title);
    setUrlError(null);
    if (!parseNickname(nickname)) {
      window.setTimeout(() => nickRef.current?.focus({ preventScroll: true }), 40);
    }
  };

  const startCheckout = async (opts: { amount: number; targetRank?: number; listingUrl?: string }) => {
    const value = (opts.listingUrl ?? matchedListing?.url ?? url).trim();
    if (!value) {
      nudgeUrlInput("need");
      return;
    }
    if (!normalizeTarget(value)) {
      nudgeUrlInput("invalid");
      return;
    }
    const owner = parseNickname(nickname);
    if (!owner) {
      setNickError(true);
      setError(copy.needNick);
      formRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
      window.setTimeout(() => nickRef.current?.focus({ preventScroll: true }), 280);
      return;
    }
    window.localStorage.setItem("footgoat.nick", owner);

    setUrlError(null);
    setNickError(false);
    let chargeAmount = opts.amount;
    if (opts.targetRank && opts.targetRank >= 1) {
      const occupant = board.listings[opts.targetRank - 1];
      if (occupant) chargeAmount = centsToDollars(occupant.bidCents) + 1;
    } else if (!opts.listingUrl) {
      chargeAmount = Math.max(opts.amount, board.claimOneEuros);
    }

    setBusy(true);
    setError("");

    const result = await createCheckoutSession({
      url: value,
      amount: chargeAmount,
      nickname: owner,
      targetRank: opts.targetRank,
      locale,
    });

    if (!result.ok) {
      setBusy(false);
      const map: Record<string, string> = {
        INVALID: copy.invalidUrl,
        NEED_NICK: copy.needNick,
        MIN_BID: copy.minBid,
        MAX_BID: copy.maxBid,
        RAISE_ONLY: copy.raiseOnly,
      };
      setError(map[result.error] || copy.checkoutError);
      return;
    }

    redirectToCheckout(result.stripeUrl);
  };

  return (
    <div className={`min-h-screen pb-16 ${heroReady ? "hero-ready" : ""}`}>
      <SiteNav locale={locale} leader={leader} />

      <main className="mx-auto w-full max-w-[760px] px-5">
        <StatsPill
          online={board.online}
          visitors={board.visitors}
          locale={locale}
          onlineLabel={copy.online}
          visitorsLabel={copy.visitorsSince}
        />

        <form
          ref={formRef}
          className="hero-form"
          onSubmit={(e) => { e.preventDefault(); startCheckout({ amount }); }}
        >
        <h1 className="hero-title mt-8 text-center text-[34px] font-extrabold leading-[1.08] tracking-[-0.04em] sm:text-[50px]">
          {copy.claimFor}{" "}
          <AppStoreUrlField
            locale={locale}
            value={url}
            onChange={(next) => {
              setUrl(next);
              if (next.trim()) setUrlError(null);
            }}
            onSelect={selectPlayer}
            error={urlError}
            inputRef={inputRef}
            disabled={busy}
            listings={board.listings}
            matchedListing={matchedListing}
          />{" "}
          {copy.claimForJoin}{" "}
          <AmountStepper
            amount={amount}
            min={board.claimOneEuros}
            locale={locale}
            amountLabel={copy.amountLabel}
            editLabel={copy.editAmount}
            increaseLabel={copy.increaseLabel}
            onChange={(next) => {
              setAmountTouched(true);
              setAmount(next);
            }}
          />
        </h1>

        <p className={`hero-hint mx-auto mt-4 max-w-[480px] text-center text-[15px] leading-relaxed text-[var(--muted)] ${bidQuote.isExisting ? "hero-hint-raise" : ""}`}>{heroHint}</p>

          <div className="mx-auto mt-7 flex w-full max-w-[560px] flex-col gap-3">
            <label className={`url-field-label flex min-h-[56px] w-full items-center gap-3 rounded-full border bg-[var(--card)] px-5 shadow-[var(--shadow)] sm:mx-auto sm:max-w-[240px] ${nickError ? "url-field-attention input-shake" : parseNickname(nickname) ? "url-field-recognized" : "border-[var(--line)]"}`}>
              <span className="text-[15px] text-[var(--muted)]">@</span>
              <input
                ref={nickRef}
                value={nickname}
                onChange={(e) => {
                  setNickname(e.target.value.replace(/^@+/, ""));
                  setNickError(false);
                }}
                placeholder={copy.nickPlaceholder}
                disabled={busy}
                maxLength={16}
                className="w-full bg-transparent text-[15px] outline-none placeholder:text-[var(--muted)] disabled:opacity-60"
                autoCapitalize="off"
                autoCorrect="off"
                spellCheck={false}
                aria-label={copy.nickLabel}
              />
            </label>
            {nickError ? (
              <p className="text-center text-[13px] text-[var(--ink)]">{copy.needNickBody}</p>
            ) : null}
            {matchedListing ? (
              <div className={`claim-preview ${nickname.trim() ? "claim-preview-live" : ""}`}>
                <AppAvatar
                  title={matchedListing.title}
                  icon={matchedListing.icon}
                  listingKey={matchedListing.listingKey}
                  size={52}
                  featured={bidQuote.projectedRank === 1}
                />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[16px] font-bold">{matchedListing.title}</p>
                  <OwnerPreview owner={matchedListing.owner} preview={nickname} copy={copy} />
                </div>
                <p className="tabular shrink-0 text-[18px] font-extrabold text-[var(--ink)]">#{bidQuote.projectedRank}</p>
              </div>
            ) : null}
            <button
              type="submit"
              disabled={submitDisabled}
              className="cta-outbid min-h-[56px] shrink-0 rounded-full px-8 text-[16px] font-semibold active:scale-[0.98] disabled:opacity-60"
            >
              {submitLabel}
            </button>
          </div>
        </form>
        <p className="hero-sub mt-3 text-center text-[13px] text-[var(--muted)]">{copy.alreadyOn}</p>
        {error ? <p className="checkout-error mt-2 text-center text-[13px] text-[var(--ink)]">{error}</p> : null}

        {leader ? (
          <HeroSpotlight
            listing={leader}
            locale={locale}
            claimAmount={amount}
            previewOwner={matchedListing?.id === leader.id ? nickname : ""}
            onSelect={() => selectPlayer(leader)}
            onClaim={() => startCheckout({ amount, targetRank: 1, listingUrl: leader.url })}
          />
        ) : null}
      </main>

      <section id="board" className="board-section mx-auto mt-8 w-full max-w-[920px] px-5">
        {board.listings.length > 0 ? (
          <p className="board-live-label mb-4 flex items-center justify-center gap-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--muted)]">
            <span className="live-dot-bright h-2 w-2 rounded-full" />
            {copy.liveLeaderboard}
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
                preview={matchedListing?.id === listing.id}
                previewOwner={matchedListing?.id === listing.id ? nickname : ""}
                onHover={setHoverRank}
                onSelect={() => selectPlayer(listing)}
                onClaim={() =>
                  startCheckout({
                    amount: centsToDollars(listing.bidCents) + 1,
                    targetRank: listing.rank,
                    listingUrl: listing.url,
                  })
                }
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
  amountLabel,
  editLabel,
  increaseLabel,
  onChange,
}: {
  amount: number;
  min: number;
  locale: Locale;
  amountLabel: string;
  editLabel: string;
  increaseLabel: string;
  onChange: (value: number) => void;
}) {
  const holdTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const holdInterval = useRef<ReturnType<typeof setInterval> | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const amountRef = useRef(amount);
  amountRef.current = amount;
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(String(amount));

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

  useEffect(() => {
    if (!editing) setDraft(String(amount));
  }, [amount, editing]);

  useEffect(() => {
    if (!editing) return;
    const node = inputRef.current;
    if (!node) return;
    node.focus();
    node.select();
  }, [editing]);

  const commitDraft = () => {
    onChange(parseBidInput(draft, min, MAX_BID_USD));
    setEditing(false);
  };

  const step = (delta: number) => {
    onChange(Math.min(MAX_BID_USD, Math.max(min, amountRef.current + delta)));
  };

  const startHold = (delta: number) => {
    if (editing) {
      const next = parseBidInput(draft, min, MAX_BID_USD);
      onChange(Math.min(MAX_BID_USD, Math.max(min, next + delta)));
      setEditing(false);
    } else {
      step(delta);
    }
    holdTimer.current = setTimeout(() => {
      holdInterval.current = setInterval(() => step(delta), 90);
    }, 320);
  };

  return (
    <span className="amount-stepper mt-2 inline-flex items-center justify-center gap-2.5 sm:mt-0" role="group" aria-label={amountLabel}>
      <span className={`amount-stepper-display ${editing ? "amount-stepper-display-editing" : ""}`}>
        {editing ? (
          <>
            {locale === "en" ? <span className="amount-affix">$</span> : null}
            <input
              ref={inputRef}
              className="amount-stepper-input"
              value={draft}
              inputMode="decimal"
              autoComplete="off"
              autoCorrect="off"
              spellCheck={false}
              aria-label={amountLabel}
              size={Math.max(2, draft.length)}
              onChange={(e) => setDraft(e.target.value)}
              onBlur={commitDraft}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  e.currentTarget.blur();
                }
                if (e.key === "Escape") {
                  setDraft(String(amountRef.current));
                  setEditing(false);
                }
              }}
            />
            {locale === "fr" ? <span className="amount-affix">$</span> : null}
          </>
        ) : (
          <button type="button" className="amount-stepper-edit" aria-label={editLabel} onClick={() => setEditing(true)}>
            <AnimatedAmount
              value={amount}
              locale={locale}
              className="text-[34px] font-extrabold text-[var(--ink)] sm:text-[44px]"
              duration={360}
            />
          </button>
        )}
      </span>
      <StepperButton
        label={increaseLabel}
        disabled={amount >= MAX_BID_USD}
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

function PlusIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 5v14M5 12h14" />
    </svg>
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
  preview,
  previewOwner,
  onHover,
  onSelect,
  onClaim,
}: {
  listing: Listing;
  locale: Locale;
  copy: ReturnType<typeof siteCopy>;
  index: number;
  flash: boolean;
  hovered: boolean;
  preview: boolean;
  previewOwner: string;
  onHover: (rank: number | null) => void;
  onSelect: () => void;
  onClaim: () => void;
}) {
  const claim = centsToDollars(listing.bidCents) + 1;
  const featured = listing.rank === 1;
  const animate = index < 6;

  return (
    <article
      id={`player-${listing.id}`}
      className={`rank-card relative mb-3 overflow-hidden rounded-[24px] border px-5 py-4 sm:pb-6 ${featured ? "rank-card-featured" : ""} ${animate ? "rank-reveal" : ""} ${flash ? "rank-card-flash" : ""} ${preview ? "rank-card-preview" : ""}`}
      style={
        {
          "--reveal-delay": `${index * 60}ms`,
          background: featured || preview ? "var(--accent-soft)" : "var(--card)",
          borderColor: featured || preview ? "rgba(0,0,0,0.14)" : "var(--line)",
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
        <button type="button" className="shrink-0 rounded-[22%]" onClick={onSelect} aria-label={listing.title}>
          <AppAvatar title={listing.title} icon={listing.icon} listingKey={listing.listingKey} size={84} featured={listing.rank === 1} />
        </button>
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <button type="button" onClick={onSelect} className="block max-w-full truncate text-left text-[18px] font-bold hover:opacity-70">
                {listing.title}
              </button>
              <div className="mt-0.5 min-w-0">
                <OwnerPreview owner={listing.owner} preview={previewOwner} copy={copy} />
              </div>
            </div>
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
