"use client";

import { AppAvatar } from "@/components/AppAvatar";
import { siteCopy, type Locale } from "@/lib/copy";
import type { Listing } from "@/lib/types";
import { type RefObject } from "react";

export type UrlFieldError = "need" | "invalid";

type Props = {
  locale: Locale;
  value: string;
  onChange: (value: string) => void;
  error: UrlFieldError | null;
  inputRef: RefObject<HTMLInputElement | null>;
  disabled?: boolean;
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

export function AppStoreUrlField({ locale, value, onChange, error, inputRef, disabled, matchedListing }: Props) {
  const copy = siteCopy(locale);
  const title = error === "invalid" ? copy.invalidUrlTitle : copy.needUrlTitle;
  const body = error === "invalid" ? copy.invalidUrlBody : copy.needUrlBody;
  const recognized = matchedListing && !error;

  return (
    <div className="url-field-wrap flex min-w-0 flex-1 flex-col gap-2">
      <label
        className={`url-field-label flex min-h-[56px] items-center gap-3 rounded-full border bg-[var(--card)] px-5 shadow-[var(--shadow)] focus-within:border-[rgba(0,0,0,0.22)] ${error ? "url-field-attention input-shake" : recognized ? "url-field-recognized" : "border-[var(--line)]"}`}
      >
        {matchedListing ? (
          <AppAvatar
            title={matchedListing.title}
            icon={matchedListing.icon}
            listingKey={matchedListing.listingKey}
            size={28}
            className="shrink-0"
          />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img src="/appstore-badge.png" alt="" width={24} height={24} className="shrink-0 rounded-[6px]" />
        )}
        <input
          ref={inputRef}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={copy.placeholder}
          disabled={disabled}
          className="w-full bg-transparent text-[15px] outline-none placeholder:text-[var(--muted)] disabled:opacity-60"
          autoCapitalize="off"
          autoCorrect="off"
          spellCheck={false}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? "url-field-hint" : undefined}
        />
      </label>

      {error ? (
        <div id="url-field-hint" className="url-hint-card" role="alert">
          <span className="url-hint-icon">
            <HintIcon />
          </span>
          <div className="min-w-0 text-left">
            <p className="url-hint-title">{title}</p>
            <p className="url-hint-body">{body}</p>
          </div>
        </div>
      ) : null}
    </div>
  );
}
