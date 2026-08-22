"use client";

import { AppAvatar } from "@/components/AppAvatar";
import { siteCopy, type Locale } from "@/lib/copy";
import { centsToDollars, formatMoney } from "@/lib/format";
import { searchPlayers } from "@/lib/player-search";
import type { Listing } from "@/lib/types";
import { useEffect, useMemo, useRef, useState, type KeyboardEvent, type RefObject } from "react";

export type UrlFieldError = "need" | "invalid";

type Props = {
  locale: Locale;
  value: string;
  onChange: (value: string) => void;
  onSelect: (listing: Listing) => void;
  error: UrlFieldError | null;
  inputRef: RefObject<HTMLInputElement | null>;
  disabled?: boolean;
  listings: Listing[];
  matchedListing?: Listing | null;
};

function HintIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" className="h-5 w-5 shrink-0">
      <path
        d="M12 8v5m0 3h.01M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function AppStoreUrlField({
  locale,
  value,
  onChange,
  onSelect,
  error,
  inputRef,
  disabled,
  listings,
  matchedListing,
}: Props) {
  const copy = siteCopy(locale);
  const wrapRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const title = error === "invalid" ? copy.invalidUrlTitle : copy.needUrlTitle;
  const body = error === "invalid" ? copy.invalidUrlBody : copy.needUrlBody;
  const recognized = matchedListing && !error;
  const hits = useMemo(() => searchPlayers(listings, value), [listings, value]);
  const showList = open && !disabled && (value.trim().length > 0 || hits.length > 0);

  useEffect(() => {
    setActive(0);
  }, [value]);

  useEffect(() => {
    const onPointer = (event: PointerEvent) => {
      if (!wrapRef.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", onPointer);
    return () => document.removeEventListener("pointerdown", onPointer);
  }, []);

  const pick = (listing: Listing) => {
    onSelect(listing);
    setOpen(false);
  };

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (!showList || !hits.length) {
      if (event.key === "Escape") setOpen(false);
      return;
    }
    if (event.key === "ArrowDown") {
      event.preventDefault();
      setActive((index) => (index + 1) % hits.length);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setActive((index) => (index - 1 + hits.length) % hits.length);
    } else if (event.key === "Enter" && open) {
      event.preventDefault();
      pick(hits[active]?.listing ?? hits[0].listing);
    } else if (event.key === "Escape") {
      event.preventDefault();
      setOpen(false);
    }
  };

  const inputWidth = Math.min(22, Math.max(8, (value.trim() || copy.placeholder).length + 1));

  return (
    <span ref={wrapRef} className="player-chip-wrap">
      <label
        className={`player-chip ${error ? "url-field-attention input-shake" : recognized ? "player-chip-on" : ""}`}
      >
        {matchedListing ? (
          <AppAvatar
            title={matchedListing.title}
            icon={matchedListing.icon}
            listingKey={matchedListing.listingKey}
            size={32}
            className="shrink-0"
          />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img src="/player-badge.svg" alt="" width={26} height={26} className="shrink-0 rounded-[7px]" />
        )}
        <input
          ref={inputRef}
          value={value}
          onChange={(e) => {
            onChange(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={onKeyDown}
          placeholder={copy.placeholder}
          disabled={disabled}
          size={inputWidth}
          className="player-chip-input"
          autoCapitalize="words"
          autoCorrect="off"
          spellCheck={false}
          role="combobox"
          aria-expanded={showList}
          aria-controls="player-suggest"
          aria-autocomplete="list"
          aria-activedescendant={showList && hits[active] ? `player-opt-${hits[active].listing.id}` : undefined}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? "url-field-hint" : undefined}
        />
      </label>

      {showList ? (
        <div id="player-suggest" className="player-suggest" role="listbox" aria-label={copy.playerSuggestions}>
          {hits.length === 0 ? (
            <p className="player-suggest-empty">{copy.noPlayerMatch}</p>
          ) : (
            hits.map((hit, index) => (
              <button
                key={hit.listing.id}
                id={`player-opt-${hit.listing.id}`}
                type="button"
                role="option"
                aria-selected={index === active}
                className={`player-suggest-row ${index === active ? "player-suggest-row-active" : ""}`}
                onMouseEnter={() => setActive(index)}
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => pick(hit.listing)}
              >
                <span className="player-suggest-rank">#{hit.listing.rank}</span>
                <AppAvatar
                  title={hit.listing.title}
                  icon={hit.listing.icon}
                  listingKey={hit.listing.listingKey}
                  size={36}
                />
                <span className="min-w-0 flex-1 text-left">
                  <span className="block truncate text-[14px] font-semibold">{hit.listing.title}</span>
                  <span className="block truncate text-[12px] text-[var(--muted)]">
                    {hit.listing.owner ? copy.ownedBy(hit.listing.owner) : copy.unclaimed}
                  </span>
                </span>
                <span className="tabular shrink-0 text-[13px] font-bold">
                  {formatMoney(centsToDollars(hit.listing.bidCents), locale)}
                </span>
              </button>
            ))
          )}
        </div>
      ) : null}

      {error ? (
        <div id="url-field-hint" className="url-hint-card player-chip-hint" role="alert">
          <span className="url-hint-icon">
            <HintIcon />
          </span>
          <div className="min-w-0 text-left">
            <p className="url-hint-title">{title}</p>
            <p className="url-hint-body">{body}</p>
          </div>
        </div>
      ) : null}
    </span>
  );
}
