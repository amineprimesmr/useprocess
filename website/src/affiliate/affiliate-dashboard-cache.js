const CACHE_PREFIX = "process-affiliate-dashboard";
const LAST_UID_KEY = "process.affiliate.uid";
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

function cacheKey(uid) {
  return `${CACHE_PREFIX}:${uid}`;
}

function readStorage(key) {
  try {
    const local = window.localStorage.getItem(key);
    if (local) return local;
    return window.sessionStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStorage(key, value) {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    try {
      window.sessionStorage.setItem(key, value);
    } catch {
      /* quota / private mode */
    }
  }
}

function removeStorage(key) {
  try {
    window.localStorage.removeItem(key);
  } catch {
    /* ignore */
  }
  try {
    window.sessionStorage.removeItem(key);
  } catch {
    /* ignore */
  }
}

export function rememberAffiliateUid(uid) {
  if (!uid) return;
  writeStorage(LAST_UID_KEY, uid);
}

export function forgetAffiliateSession(uid) {
  if (uid) clearDashboardCache(uid);
  removeStorage(LAST_UID_KEY);
}

export function peekAffiliateSession() {
  try {
    const uid =
      window.localStorage.getItem(LAST_UID_KEY) || window.sessionStorage.getItem(LAST_UID_KEY) || findCachedUid();
    if (!uid) return null;
    rememberAffiliateUid(uid);
    return { uid, dashboard: readDashboardCache(uid) };
  } catch {
    return null;
  }
}

function findCachedUid() {
  const prefix = `${CACHE_PREFIX}:`;
  for (const store of [window.localStorage, window.sessionStorage]) {
    for (let i = 0; i < store.length; i++) {
      const key = store.key(i);
      if (key?.startsWith(prefix)) return key.slice(prefix.length);
    }
  }
  return "";
}

export function readDashboardCache(uid) {
  if (!uid) return null;
  try {
    const raw = readStorage(cacheKey(uid));
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed?.data || !parsed?.at) return null;
    if (Date.now() - parsed.at > CACHE_TTL_MS) return null;
    return parsed.data;
  } catch {
    return null;
  }
}

export function writeDashboardCache(uid, data) {
  if (!uid || !data) return;
  rememberAffiliateUid(uid);
  writeStorage(
    cacheKey(uid),
    JSON.stringify({
      at: Date.now(),
      data,
    })
  );
}

export function clearDashboardCache(uid) {
  if (!uid) return;
  removeStorage(cacheKey(uid));
}

export function buildOptimisticDashboard({ affiliateId, displayName, code, status, codes }) {
  const normalizedStatus = status || "pending";
  const codeRows =
    codes?.length > 0
      ? codes
      : code
        ? [{ code, displayName: displayName || code, status: normalizedStatus }]
        : [];

  return {
    ok: true,
    affiliateId,
    displayName: displayName || "",
    status: normalizedStatus,
    payoutMethod: null,
    stripeConnect: {
      accountId: null,
      onboardingComplete: false,
      payoutsEnabled: false,
      detailsSubmitted: false,
      requirementsDue: [],
    },
    primaryCode: code || codeRows[0]?.code || "",
    codes: codeRows,
    stats: {
      linkViews: 0,
      storeClicks: 0,
      referredCount: 0,
      paywallCount: 0,
      paidCount: 0,
      activeSubscribers: 0,
      pendingCents: 0,
      payableCents: 0,
      paidCents: 0,
      lifetimeCents: 0,
    },
    series: {
      days: [],
      linkViews: [],
      storeClicks: [],
      attributions: [],
      paywalls: [],
      sales: [],
      earningsCents: [],
    },
    recentCommissions: [],
    payouts: [],
    tiktok: {
      apiReady: false,
      accounts: [],
      totals: { accounts: 0, connected: 0, followers: 0, likes: 0, videoCount: 0, views: 0, comments: 0, shares: 0 },
    },
    __optimistic: true,
  };
}
