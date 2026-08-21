"use client";

import { formatMoney } from "@/lib/format";
import type { Locale } from "@/lib/copy";
import { useEffect, useRef, useState, type CSSProperties } from "react";

type Props = {
  value: number;
  locale: Locale;
  className?: string;
  duration?: number;
};

type RollState = {
  from: number;
  to: number;
  key: number;
};

export function AnimatedAmount({ value, locale, className = "", duration = 380 }: Props) {
  const mounted = useRef(false);
  const [roll, setRoll] = useState<RollState>({ from: value, to: value, key: 0 });
  const [settled, setSettled] = useState(value);

  useEffect(() => {
    if (!mounted.current) {
      mounted.current = true;
      setSettled(value);
      return;
    }
    if (value === settled) return;

    setRoll((prev) => ({
      from: settled,
      to: value,
      key: prev.key + 1,
    }));
  }, [value, settled]);

  useEffect(() => {
    if (roll.from === roll.to) return;
    const t = window.setTimeout(() => setSettled(roll.to), duration);
    return () => window.clearTimeout(t);
  }, [roll, duration]);

  const animating = roll.from !== roll.to;
  const up = roll.to > roll.from;
  const fromText = formatMoney(roll.from, locale);
  const toText = formatMoney(roll.to, locale);

  if (!animating) {
    return (
      <span className={`rolling-amount tabular ${className}`} aria-live="polite" aria-atomic="true">
        {formatMoney(settled, locale)}
      </span>
    );
  }

  return (
    <span
      className={`rolling-amount tabular ${className}`}
      aria-live="polite"
      aria-atomic="true"
      style={{ "--roll-ms": `${duration}ms` } as CSSProperties}
    >
      <span className="rolling-viewport">
        <span
          key={roll.key}
          className={`rolling-track ${up ? "rolling-track-up" : "rolling-track-down"}`}
        >
          {up ? (
            <>
              <span className="rolling-row">{fromText}</span>
              <span className="rolling-row">{toText}</span>
            </>
          ) : (
            <>
              <span className="rolling-row">{toText}</span>
              <span className="rolling-row">{fromText}</span>
            </>
          )}
        </span>
      </span>
    </span>
  );
}
