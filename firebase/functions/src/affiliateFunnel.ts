import * as admin from "firebase-admin";
import {
  EMPTY_DAILY_COUNTS,
  emptyDailySeries,
  hashKey,
  isLikelyBotUserAgent,
  lastNDayKeys,
  sanitizeVisitorId,
  utcDayKey,
  utcHourKey,
  type AffiliateDailyCounts,
} from "./affiliateAnalytics";
import { bumpAffiliateDaily, db, resolveAffiliateByCode } from "./affiliateShared";

const CLICK_BUDGET_PER_IP_HOUR = 40;

async function allowClickBudget(ip: string): Promise<boolean> {
  const normalized = String(ip || "").trim();
  if (!normalized || normalized === "unknown") return true;

  const ref = db().collection("affiliateClickBudget").doc(`${hashKey(normalized)}_${utcHourKey()}`);
  const next = await db().runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const n = Number(snap.data()?.n ?? 0) + 1;
    transaction.set(ref, { n, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    return n;
  });
  return next <= CLICK_BUDGET_PER_IP_HOUR;
}

export async function trackAffiliateLinkEvent(params: {
  code: string;
  event: "view" | "store";
  visitorId: string;
  userAgent?: string;
  ip?: string;
}): Promise<{ ok: true; counted: boolean; reason?: string }> {
  if (isLikelyBotUserAgent(params.userAgent || "")) {
    return { ok: true, counted: false, reason: "bot" };
  }

  const visitorId = sanitizeVisitorId(params.visitorId);
  if (visitorId.length < 8) {
    return { ok: true, counted: false, reason: "invalid_visitor" };
  }

  const resolved = await resolveAffiliateByCode(params.code);
  if (!resolved) {
    return { ok: true, counted: false, reason: "not_found" };
  }

  const allowed = await allowClickBudget(params.ip || "");
  if (!allowed) {
    return { ok: true, counted: false, reason: "rate_limited" };
  }

  const event = params.event === "store" ? "store" : "view";
  const statField = event === "store" ? "storeClicks" : "linkViews";
  const dailyField = event === "store" ? "storeClicks" : "linkViews";
  const day = utcDayKey();
  const sessionRef = db()
    .collection("affiliates")
    .doc(resolved.affiliateId)
    .collection(event === "store" ? "storeSessions" : "linkSessions")
    .doc(`${day}_${visitorId}`);
  const affiliateRef = db().collection("affiliates").doc(resolved.affiliateId);

  let counted = false;
  await db().runTransaction(async (transaction) => {
    const existing = await transaction.get(sessionRef);
    if (existing.exists) return;

    const now = admin.firestore.Timestamp.now();
    transaction.set(sessionRef, {
      visitorId,
      event,
      createdAt: now,
    });
    transaction.set(
      affiliateRef,
      {
        [`stats.${statField}`]: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
      },
      { merge: true }
    );
    bumpAffiliateDaily(transaction, resolved.affiliateId, { [dailyField]: 1 }, now);
    counted = true;
  });

  return { ok: true, counted };
}

export async function trackAffiliatePaywall(params: {
  code: string;
  visitorId: string;
  uid?: string | null;
}): Promise<{ ok: true; counted: boolean; reason?: string }> {
  const visitorId = sanitizeVisitorId(params.visitorId);
  if (visitorId.length < 8) {
    return { ok: true, counted: false, reason: "invalid_visitor" };
  }

  const resolved = await resolveAffiliateByCode(params.code);
  if (!resolved) {
    return { ok: true, counted: false, reason: "not_found" };
  }

  const uid = String(params.uid || "").trim();
  const funnelCol = db()
    .collection("affiliates")
    .doc(resolved.affiliateId)
    .collection("funnel");
  const visitorRef = funnelCol.doc(`paywall_v_${visitorId}`);
  const uidRef = uid ? funnelCol.doc(`paywall_u_${uid}`) : null;
  const affiliateRef = db().collection("affiliates").doc(resolved.affiliateId);

  let counted = false;
  await db().runTransaction(async (transaction) => {
    const visitorSnap = await transaction.get(visitorRef);
    const uidSnap = uidRef ? await transaction.get(uidRef) : null;
    if (visitorSnap.exists || uidSnap?.exists) return;

    const now = admin.firestore.Timestamp.now();
    const payload = {
      event: "paywall",
      visitorId,
      uid: uid || null,
      createdAt: now,
    };
    transaction.set(visitorRef, payload);
    if (uidRef) transaction.set(uidRef, payload);
    transaction.set(
      affiliateRef,
      {
        "stats.paywallCount": admin.firestore.FieldValue.increment(1),
        updatedAt: now,
      },
      { merge: true }
    );
    bumpAffiliateDaily(transaction, resolved.affiliateId, { paywalls: 1 }, now);
    counted = true;
  });

  return { ok: true, counted };
}

export async function readAffiliateDailySeries(
  affiliateId: string,
  days = 30
): Promise<ReturnType<typeof emptyDailySeries>> {
  const series = emptyDailySeries(days);
  const keys = lastNDayKeys(days);
  const start = keys[0];
  const end = keys[keys.length - 1];
  if (!start || !end) return series;

  const snap = await db()
    .collection("affiliates")
    .doc(affiliateId)
    .collection("daily")
    .where("day", ">=", start)
    .where("day", "<=", end)
    .get();

  const byDay = new Map(snap.docs.map((doc) => [doc.id, doc.data() || {}]));
  keys.forEach((day, index) => {
    const row = { ...EMPTY_DAILY_COUNTS, ...(byDay.get(day) || {}) } as AffiliateDailyCounts;
    series.linkViews[index] = Number(row.linkViews || 0);
    series.storeClicks[index] = Number(row.storeClicks || 0);
    series.attributions[index] = Number(row.attributions || 0);
    series.paywalls[index] = Number(row.paywalls || 0);
    series.sales[index] = Number(row.sales || 0);
    series.earningsCents[index] = Number(row.earningsCents || 0);
  });
  return series;
}
