"use client";

import { formatCompactCount } from "@/lib/format";
import type { Locale } from "@/lib/copy";
import { useEffect, useRef, useState } from "react";

type Props = {
  online: number;
  visitors: number;
  locale: Locale;
  onlineLabel: string;
  visitorsLabel: string;
};

export function StatsPill({ online, visitors, locale, onlineLabel, visitorsLabel }: Props) {
  const prevOnline = useRef(online);
  const prevVisitors = useRef(visitors);
  const [plusOnline, setPlusOnline] = useState<number | null>(null);
  const [plusVisitors, setPlusVisitors] = useState<number | null>(null);

  useEffect(() => {
    if (online > prevOnline.current) {
      setPlusOnline(online - prevOnline.current);
      const t = window.setTimeout(() => setPlusOnline(null), 2200);
      prevOnline.current = online;
      return () => window.clearTimeout(t);
    }
    prevOnline.current = online;
  }, [online]);

  useEffect(() => {
    if (visitors > prevVisitors.current) {
      setPlusVisitors(visitors - prevVisitors.current);
      const t = window.setTimeout(() => setPlusVisitors(null), 2200);
      prevVisitors.current = visitors;
      return () => window.clearTimeout(t);
    }
    prevVisitors.current = visitors;
  }, [visitors]);

  return (
    <div className="stats-pill mt-4 flex justify-center">
      <div className="stats-pill-dark inline-flex flex-wrap items-center justify-center gap-x-2 gap-y-1 rounded-full px-4 py-2 text-[13px] sm:gap-x-2.5 sm:px-5 sm:py-2.5">
        <span className="inline-flex items-center gap-1.5">
          <span className="live-dot-bright h-2.5 w-2.5 shrink-0 rounded-full" />
          <span className="tabular-nums font-medium text-white">{formatCompactCount(online, locale)}</span>
          {plusOnline !== null ? (
            <span className="stat-plus tabular-nums text-[11px] font-bold">+{plusOnline}</span>
          ) : null}
          <span className="text-white/50">{onlineLabel}</span>
        </span>
        <span className="hidden text-white/25 sm:inline">·</span>
        <span className="inline-flex items-center gap-1.5">
          <span className="tabular-nums font-medium text-white">{formatCompactCount(visitors, locale)}</span>
          {plusVisitors !== null ? (
            <span className="stat-plus tabular-nums text-[11px] font-bold">+{plusVisitors}</span>
          ) : null}
          <span className="text-white/50">{visitorsLabel}</span>
        </span>
      </div>
    </div>
  );
}
