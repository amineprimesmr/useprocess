import { buildOptimisticDashboard } from "./affiliate-dashboard-cache.js";

const LOCAL_UID = "local-preview";

export function isAffiliateLocalPreview() {
  if (!import.meta.env.DEV) return false;
  if (typeof window === "undefined") return false;
  const host = window.location.hostname;
  if (host !== "localhost" && host !== "127.0.0.1") return false;
  const params = new URLSearchParams(window.location.search);
  if (params.get("landing") === "1") return false;
  return true;
}

function localSeries(days = 30) {
  const series = {
    days: [],
    linkViews: [],
    storeClicks: [],
    attributions: [],
    paywalls: [],
    sales: [],
    earningsCents: [],
  };
  const today = new Date();
  for (let i = days - 1; i >= 0; i -= 1) {
    const day = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - i));
    const wave = Math.max(4, Math.round(12 + Math.sin(i / 3.2) * 7 + (i % 6)));
    series.days.push(day.toISOString().slice(0, 10));
    series.linkViews.push(wave);
    series.storeClicks.push(Math.round(wave * 0.42));
    series.attributions.push(Math.round(wave * 0.2));
    series.paywalls.push(Math.round(wave * 0.11));
    series.sales.push(i % 5 === 0 ? 1 : 0);
    series.earningsCents.push(i % 5 === 0 ? 250 : 0);
  }
  return series;
}

const series = localSeries();
const visits = series.linkViews.reduce((sum, n) => sum + n, 0);
const storeClicks = series.storeClicks.reduce((sum, n) => sum + n, 0);
const installs = series.attributions.reduce((sum, n) => sum + n, 0);
const paywalls = series.paywalls.reduce((sum, n) => sum + n, 0);
const sales = series.sales.reduce((sum, n) => sum + n, 0);
const lifetimeCents = series.earningsCents.reduce((sum, n) => sum + n, 0);

export const LOCAL_PREVIEW_USER = {
  uid: LOCAL_UID,
  email: "amine@localhost",
  displayName: "Amine",
  isAnonymous: false,
  getIdToken: async () => "local-preview",
};

export const LOCAL_PREVIEW_DASHBOARD = {
  ...buildOptimisticDashboard({
    affiliateId: LOCAL_UID,
    displayName: "Amine",
    code: "AMINE",
    status: "active",
  }),
  stats: {
    linkViews: visits,
    storeClicks,
    referredCount: installs,
    paywallCount: paywalls,
    paidCount: sales,
    activeSubscribers: sales,
    pendingCents: 750,
    payableCents: 500,
    paidCents: lifetimeCents - 1250,
    lifetimeCents,
  },
  series,
  recentCommissions: [
    {
      id: "local-1",
      inviteeUid: "u1",
      eventType: "INITIAL_PURCHASE",
      productId: "process_weekly",
      commissionCents: 250,
      currency: "EUR",
      status: "payable",
      createdAt: Date.now() - 2 * 86400000,
      holdUntil: null,
    },
    {
      id: "local-2",
      inviteeUid: "u2",
      eventType: "INITIAL_PURCHASE",
      productId: "process_weekly",
      commissionCents: 250,
      currency: "EUR",
      status: "pending",
      createdAt: Date.now() - 5 * 86400000,
      holdUntil: Date.now() + 9 * 86400000,
    },
  ],
  __localPreview: true,
};

export const LOCAL_PREVIEW_CLIPPERS = [
  {
    affiliateId: LOCAL_UID,
    displayName: "Amine",
    code: "AMINE",
    isYou: true,
    stats: LOCAL_PREVIEW_DASHBOARD.stats,
  },
  {
    affiliateId: "manny",
    displayName: "Manny",
    code: "MANNY",
    isYou: false,
    stats: {
      linkViews: 4200,
      referredCount: 310,
      paywallCount: 90,
      paidCount: 41,
      lifetimeCents: 10250,
    },
  },
  {
    affiliateId: "lea",
    displayName: "Léa",
    code: "LEA",
    isYou: false,
    stats: {
      linkViews: 1800,
      referredCount: 140,
      paywallCount: 44,
      paidCount: 18,
      lifetimeCents: 4500,
    },
  },
  {
    affiliateId: "nico",
    displayName: "Nico",
    code: "NICO",
    isYou: false,
    stats: {
      linkViews: 960,
      referredCount: 70,
      paywallCount: 21,
      paidCount: 7,
      lifetimeCents: 1750,
    },
  },
];
