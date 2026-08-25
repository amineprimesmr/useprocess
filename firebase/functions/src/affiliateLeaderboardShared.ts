export const CLIPPER_SORTS = ["earnings", "sales", "installs", "visits", "paywalls"] as const;
export type ClipperSort = (typeof CLIPPER_SORTS)[number];

export type ClipperStats = {
  lifetimeCents: number;
  paidCount: number;
  referredCount: number;
  linkViews: number;
  paywallCount: number;
};

export type PublicClipper = {
  displayName: string;
  code: string;
  isYou: boolean;
  stats: ClipperStats;
};

export type RankedClipper = PublicClipper & { rank: number };

function num(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) ? Math.max(0, Math.round(n)) : 0;
}

export function normalizeClipperSort(raw: unknown): ClipperSort {
  const value = String(raw || "").trim();
  return (CLIPPER_SORTS as readonly string[]).includes(value) ? (value as ClipperSort) : "earnings";
}

export function clipperMetric(stats: ClipperStats, sort: ClipperSort): number {
  switch (sort) {
    case "sales":
      return stats.paidCount;
    case "installs":
      return stats.referredCount;
    case "visits":
      return stats.linkViews;
    case "paywalls":
      return stats.paywallCount;
    default:
      return stats.lifetimeCents;
  }
}

export function toPublicClipper(params: {
  affiliateId: string;
  viewerAffiliateId: string;
  displayName?: unknown;
  primaryCode?: unknown;
  codes?: unknown;
  stats?: unknown;
}): PublicClipper {
  const statsRaw =
    params.stats && typeof params.stats === "object" ? (params.stats as Record<string, unknown>) : {};
  const codes = Array.isArray(params.codes)
    ? params.codes.map((value) => String(value || "").trim()).filter(Boolean)
    : [];
  const code = String(params.primaryCode || codes[0] || "")
    .trim()
    .slice(0, 40);
  const displayName =
    String(params.displayName || "")
      .trim()
      .slice(0, 80) ||
    code ||
    "Clipper";

  return {
    displayName,
    code,
    isYou: Boolean(params.affiliateId) && params.affiliateId === params.viewerAffiliateId,
    stats: {
      lifetimeCents: num(statsRaw.lifetimeCents),
      paidCount: num(statsRaw.paidCount),
      referredCount: num(statsRaw.referredCount),
      linkViews: num(statsRaw.linkViews),
      paywallCount: num(statsRaw.paywallCount),
    },
  };
}

export function rankClippers(rows: PublicClipper[], sort: ClipperSort = "earnings"): RankedClipper[] {
  const sorted = [...rows].sort((a, b) => {
    const primary = clipperMetric(b.stats, sort) - clipperMetric(a.stats, sort);
    if (primary) return primary;
    const earnings = b.stats.lifetimeCents - a.stats.lifetimeCents;
    if (earnings) return earnings;
    const sales = b.stats.paidCount - a.stats.paidCount;
    if (sales) return sales;
    const installs = b.stats.referredCount - a.stats.referredCount;
    if (installs) return installs;
    const visits = b.stats.linkViews - a.stats.linkViews;
    if (visits) return visits;
    return a.displayName.localeCompare(b.displayName, "en", { sensitivity: "base" });
  });
  return sorted.map((row, index) => ({ ...row, rank: index + 1 }));
}
