"use client";

import { BrandLogo } from "@/components/BrandLogo";
import { useLocale } from "@/hooks/useLocale";
import { useEffect, useState } from "react";
import { formatEuros, centsToEuros } from "@/lib/format";
import { siteCopy, type Locale } from "@/lib/copy";

type SessionState = {
  paid: boolean;
  rank: number | null;
  title: string;
  bidCents: number;
};

async function fulfillSession(id: string, attempts = 4): Promise<SessionState> {
  let last: SessionState = { paid: false, rank: null, title: "", bidCents: 0 };
  for (let i = 0; i < attempts; i += 1) {
    const res = await fetch(`/api/session?session_id=${encodeURIComponent(id)}`, { cache: "no-store" });
    if (!res.ok) {
      await new Promise((r) => setTimeout(r, 400 * (i + 1)));
      continue;
    }
    last = (await res.json()) as SessionState;
    if (last.paid && last.rank) return last;
    await new Promise((r) => setTimeout(r, 400 * (i + 1)));
  }
  return last;
}

export function SuccessClient({ locale: initialLocale }: { locale: Locale }) {
  const locale = useLocale(initialLocale);
  const [state, setState] = useState<SessionState | null>(null);

  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get("session_id");
    if (!id) return;
    fulfillSession(id)
      .then(setState)
      .catch(() => setState({ paid: false, rank: null, title: "", bidCents: 0 }));
  }, []);

  const copy = siteCopy(locale);

  return (
    <div className="grid min-h-screen place-items-center px-5">
      <div className="rise w-full max-w-[440px] rounded-[28px] border border-[var(--line)] bg-[var(--card)] px-8 py-10 text-center shadow-[var(--shadow)]">
        <div className="relative mx-auto mb-5 w-fit">
          <BrandLogo size={72} priority />
          <span className="absolute -bottom-1 -right-1 grid h-7 w-7 place-items-center rounded-full bg-[var(--ink)] text-sm font-bold text-white shadow-[0_4px_12px_rgba(0,0,0,0.25)]">
            ✓
          </span>
        </div>
        <h1 className="text-[28px] font-extrabold tracking-tight">{copy.successTitle}</h1>
        <p className="mt-3 text-[15px] leading-relaxed text-[var(--muted)]">{copy.successBody}</p>
        {state?.title ? (
          <p className="mt-5 text-[15px] font-medium">
            {state.title}
            {state.rank ? ` · #${state.rank}` : ""} · {formatEuros(centsToEuros(state.bidCents), locale)}
          </p>
        ) : state === null ? (
          <p className="mt-5 text-[14px] text-[var(--muted)]">{copy.confirming}</p>
        ) : null}
        <a
          href="/"
          className="btn-primary mt-8 inline-flex min-h-[52px] items-center rounded-full px-6 font-semibold"
        >
          {copy.backHome}
        </a>
      </div>
    </div>
  );
}
