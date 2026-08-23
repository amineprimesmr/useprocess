const CACHE_PREFIX = "process-affiliate-dashboard";
const CACHE_TTL_MS = 5 * 60 * 1000;

function cacheKey(uid) {
  return `${CACHE_PREFIX}:${uid}`;
}

export function readDashboardCache(uid) {
  if (!uid) return null;
  try {
    const raw = sessionStorage.getItem(cacheKey(uid));
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
  try {
    sessionStorage.setItem(
      cacheKey(uid),
      JSON.stringify({
        at: Date.now(),
        data,
      })
    );
  } catch {
    /* quota / private mode */
  }
}

export function clearDashboardCache(uid) {
  if (!uid) return;
  try {
    sessionStorage.removeItem(cacheKey(uid));
  } catch {
    /* ignore */
  }
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
      referredCount: 0,
      activeSubscribers: 0,
      pendingCents: 0,
      payableCents: 0,
      paidCents: 0,
      lifetimeCents: 0,
    },
    recentCommissions: [],
    payouts: [],
    __optimistic: true,
  };
}
