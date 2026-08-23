import * as admin from "firebase-admin";
import { isPaidPurchaseEvent } from "./revenueCat";
import {
  COMMISSION_HOLD_DAYS,
  COMMISSION_NET_FACTOR,
  COMMISSION_RATE,
  LIFETIME_PRODUCT_ID,
  commissionDocId as sharedCommissionDocId,
  commissionFromRevenueCatEvent,
  type CommissionStatus,
} from "./commissionShared";
import { normalizeReferralCode, resolveReferrerUserId, isValidReferralCode } from "./referralShared";

export const AFFILIATE_COMMISSION_RATE = COMMISSION_RATE;
export const AFFILIATE_HOLD_DAYS = COMMISSION_HOLD_DAYS;
export const AFFILIATE_NET_FACTOR = COMMISSION_NET_FACTOR;
export { LIFETIME_PRODUCT_ID };

export type AffiliateStatus = "pending" | "active" | "suspended";
export type AffiliateAttributionStatus = "active" | "churned" | "refunded";
export type AffiliateCommissionStatus = CommissionStatus;

export interface AffiliateCodeDoc {
  affiliateId: string;
  affiliateCode: string;
  displayName: string;
  status: AffiliateStatus;
  commissionRate: number;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

export interface AffiliateDoc {
  uid?: string;
  displayName: string;
  email?: string;
  /** @deprecated Legacy PayPal field — payouts use Stripe Connect */
  paypalEmail?: string | null;
  stripeAccountId?: string | null;
  stripeOnboardingComplete?: boolean;
  stripePayoutsEnabled?: boolean;
  stripeDetailsSubmitted?: boolean;
  stripeRequirementsDue?: string[];
  payoutMethod?: "stripe" | null;
  status: AffiliateStatus;
  codes: string[];
  primaryCode?: string;
  stats: {
    referredCount: number;
    activeSubscribers: number;
    pendingCents: number;
    payableCents: number;
    paidCents: number;
    lifetimeCents: number;
  };
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

export interface AffiliateCommissionDoc {
  affiliateId: string;
  inviteeUid: string;
  affiliateCode: string;
  rcEventId: string;
  rcEventType: string;
  productId?: string;
  grossCents: number;
  netCents: number;
  commissionCents: number;
  commissionRate: number;
  currency: string;
  status: AffiliateCommissionStatus;
  holdUntil: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
  payableAt?: admin.firestore.Timestamp;
  paidAt?: admin.firestore.Timestamp;
  payoutId?: string;
  clawedBackAt?: admin.firestore.Timestamp;
}

export function db() {
  return admin.firestore();
}

export function normalizeAffiliateCode(raw: string): string {
  return String(raw || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "")
    .replace(/[^A-Z0-9-]/g, "")
    .slice(0, 24);
}

export function affiliateHttpStatus(message: string): number {
  if (message === "UNAUTHORIZED") return 401;
  if (message === "FORBIDDEN") return 403;
  if (message === "INVALID_CODE") return 400;
  if (message === "INVALID_APP_CHECK") return 401;
  if (message === "SELF_ATTRIBUTION") return 400;
  if (message === "ALREADY_ATTRIBUTED") return 409;
  if (message === "AFFILIATE_NOT_FOUND") return 404;
  if (message === "AFFILIATE_INACTIVE") return 403;
  if (message === "AFFILIATE_NOT_LINKED") return 403;
  if (message === "STRIPE_NOT_LINKED") return 404;
  if (message === "STRIPE_NOT_CONFIGURED") return 503;
  if (message === "STRIPE_NOT_READY") return 400;
  if (message === "CODE_CONFLICT") return 409;
  if (message === "INVALID_ADMIN") return 401;
  if (message === "INVALID_TEXT") return 400;
  if (message === "INVALID_PAYOUT") return 400;
  return 500;
}

export async function resolveAffiliateByCode(
  code: string
): Promise<{ affiliateId: string; doc: AffiliateCodeDoc } | null> {
  const normalized = normalizeAffiliateCode(code);
  if (!normalized) return null;

  const snapshot = await db().collection("affiliateCodes").doc(normalized).get();
  if (!snapshot.exists) return null;

  const data = snapshot.data() as AffiliateCodeDoc | undefined;
  if (!data?.affiliateId || data.status !== "active") return null;

  return { affiliateId: data.affiliateId, doc: data };
}

export async function resolveCodeKind(
  code: string
): Promise<
  | { type: "affiliate"; code: string; displayName: string; affiliateId: string }
  | { type: "referral"; code: string; displayName?: string; referrerUserId: string }
  | null
> {
  const normalizedAffiliate = normalizeAffiliateCode(code);
  if (normalizedAffiliate) {
    const affiliateSnap = await db()
      .collection("affiliateCodes")
      .doc(normalizedAffiliate)
      .get();
    if (affiliateSnap.exists) {
      const data = affiliateSnap.data() as AffiliateCodeDoc | undefined;
      if (data?.affiliateId && data.status === "active") {
        return {
          type: "affiliate",
          code: normalizedAffiliate,
          displayName: data.displayName ?? normalizedAffiliate,
          affiliateId: data.affiliateId,
        };
      }
    }
  }

  const normalizedReferral = normalizeReferralCode(code);
  if (!isValidReferralCode(normalizedReferral)) return null;
  const referrerUserId = await resolveReferrerUserId(normalizedReferral);
  if (!referrerUserId) return null;

  return {
    type: "referral",
    code: normalizedReferral,
    referrerUserId,
  };
}

export function commissionDocId(affiliateId: string, rcEventId: string): string {
  return sharedCommissionDocId(affiliateId, rcEventId);
}

export { commissionFromRevenueCatEvent };

export async function registerAffiliateAttribution(params: {
  affiliateId: string;
  affiliateCode: string;
  inviteeUid: string;
  displayName: string;
}): Promise<void> {
  const affiliateRef = db().collection("affiliates").doc(params.affiliateId);
  const affiliateSnap = await affiliateRef.get();
  if (!affiliateSnap.exists) throw new Error("AFFILIATE_NOT_FOUND");

  const affiliate = affiliateSnap.data() as AffiliateDoc | undefined;
  if (!affiliate || affiliate.status !== "active") {
    throw new Error("AFFILIATE_INACTIVE");
  }

  if (affiliate.uid && affiliate.uid === params.inviteeUid) {
    throw new Error("SELF_ATTRIBUTION");
  }

  const referredMetaRef = db()
    .collection("users")
    .doc(params.inviteeUid)
    .collection("affiliateMeta")
    .doc("referredBy");

  const attributionRef = affiliateRef
    .collection("attributions")
    .doc(params.inviteeUid);

  await db().runTransaction(async (transaction) => {
    const existing = await transaction.get(referredMetaRef);
    if (existing.exists) throw new Error("ALREADY_ATTRIBUTED");

    const now = admin.firestore.Timestamp.now();
    transaction.set(referredMetaRef, {
      affiliateId: params.affiliateId,
      affiliateCode: params.affiliateCode,
      registeredAt: now,
      status: "active" satisfies AffiliateAttributionStatus,
    });

    transaction.set(attributionRef, {
      inviteeUid: params.inviteeUid,
      affiliateCode: params.affiliateCode,
      displayName: params.displayName.slice(0, 80),
      registeredAt: now,
      status: "active" satisfies AffiliateAttributionStatus,
    });

    transaction.set(
      affiliateRef,
      {
        "stats.referredCount": admin.firestore.FieldValue.increment(1),
        updatedAt: now,
      },
      { merge: true }
    );
  });
}

export async function getAffiliateAttributionForUser(
  inviteeUid: string
): Promise<
  | {
      affiliateId: string;
      affiliateCode: string;
      status: AffiliateAttributionStatus;
    }
  | null
> {
  const snap = await db()
    .collection("users")
    .doc(inviteeUid)
    .collection("affiliateMeta")
    .doc("referredBy")
    .get();

  if (!snap.exists) return null;
  const data = snap.data() ?? {};
  const affiliateId = data.affiliateId as string | undefined;
  const affiliateCode = data.affiliateCode as string | undefined;
  const status = (data.status as AffiliateAttributionStatus | undefined) ?? "active";
  if (!affiliateId || !affiliateCode) return null;
  if (status === "refunded") return null;
  return { affiliateId, affiliateCode, status };
}

export async function accrueAffiliateCommission(params: {
  inviteeUid: string;
  event: any;
}): Promise<{ created: boolean; commissionId?: string; skipped?: string }> {
  const eventType = String(params.event?.type ?? "");
  const rcEventId = String(params.event?.id ?? params.event?.event_timestamp_ms ?? "");
  if (!rcEventId) return { created: false, skipped: "NO_EVENT_ID" };

  const isRenewal = eventType === "RENEWAL" && isPaidPurchaseEvent(params.event);
  const isInitial =
    eventType === "INITIAL_PURCHASE" && isPaidPurchaseEvent(params.event);
  if (!isRenewal && !isInitial) {
    return { created: false, skipped: eventType || "UNSUPPORTED_EVENT" };
  }

  const attribution = await getAffiliateAttributionForUser(params.inviteeUid);
  if (!attribution || attribution.status !== "active") {
    return { created: false, skipped: "NOT_ATTRIBUTED" };
  }

  const amounts = commissionFromRevenueCatEvent(params.event);
  if (!amounts) return { created: false, skipped: "NO_COMMISSION" };

  const commissionId = commissionDocId(attribution.affiliateId, rcEventId);
  const commissionRef = db().collection("affiliateCommissions").doc(commissionId);
  const affiliateRef = db().collection("affiliates").doc(attribution.affiliateId);

  const existing = await commissionRef.get();
  if (existing.exists) return { created: false, skipped: "DUPLICATE" };

  const now = admin.firestore.Timestamp.now();
  const holdUntil = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + AFFILIATE_HOLD_DAYS * 86_400_000
  );

  const commission: AffiliateCommissionDoc = {
    affiliateId: attribution.affiliateId,
    inviteeUid: params.inviteeUid,
    affiliateCode: attribution.affiliateCode,
    rcEventId,
    rcEventType: eventType,
    productId: amounts.productId,
    grossCents: amounts.grossCents,
    netCents: amounts.netCents,
    commissionCents: amounts.commissionCents,
    commissionRate: amounts.commissionRate,
    currency: amounts.currency,
    status: "pending_hold",
    holdUntil,
    createdAt: now,
  };

  await db().runTransaction(async (transaction) => {
    transaction.set(commissionRef, commission);
    transaction.set(
      affiliateRef,
      {
        "stats.pendingCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
        "stats.lifetimeCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
        updatedAt: now,
      },
      { merge: true }
    );
    transaction.set(
      affiliateRef.collection("attributions").doc(params.inviteeUid),
      {
        lastCommissionAt: now,
        lastProductId: amounts.productId ?? null,
      },
      { merge: true }
    );
  });

  return { created: true, commissionId };
}

export async function clawbackAffiliateCommission(params: {
  inviteeUid: string;
  event: any;
}): Promise<{ clawed: number }> {
  const attribution = await getAffiliateAttributionForUser(params.inviteeUid);
  if (!attribution) return { clawed: 0 };

  const originalTransactionId = String(
    params.event?.original_transaction_id ??
      params.event?.transaction_id ??
      params.event?.id ??
      ""
  );
  if (!originalTransactionId) return { clawed: 0 };

  const commissions = await db()
    .collection("affiliateCommissions")
    .where("affiliateId", "==", attribution.affiliateId)
    .where("inviteeUid", "==", params.inviteeUid)
    .limit(50)
    .get();

  let clawed = 0;
  const batch = db().batch();
  const now = admin.firestore.Timestamp.now();
  const affiliateRef = db().collection("affiliates").doc(attribution.affiliateId);

  for (const doc of commissions.docs) {
    const data = doc.data() as AffiliateCommissionDoc;
    if (data.status === "clawed_back" || data.status === "paid") continue;
    if (
      data.rcEventId !== originalTransactionId &&
      !String(data.rcEventId).includes(originalTransactionId)
    ) {
      continue;
    }

    clawed += data.commissionCents;
    batch.set(
      doc.ref,
      {
        status: "clawed_back",
        clawedBackAt: now,
      },
      { merge: true }
    );

    const statField =
      data.status === "payable" ? "payableCents" : "pendingCents";
    batch.set(
      affiliateRef,
      {
        [`stats.${statField}`]: admin.firestore.FieldValue.increment(-data.commissionCents),
        "stats.lifetimeCents": admin.firestore.FieldValue.increment(-data.commissionCents),
        updatedAt: now,
      },
      { merge: true }
    );
  }

  batch.set(
    db()
      .collection("users")
      .doc(params.inviteeUid)
      .collection("affiliateMeta")
      .doc("referredBy"),
    { status: "refunded" satisfies AffiliateAttributionStatus },
    { merge: true }
  );

  batch.set(
    affiliateRef.collection("attributions").doc(params.inviteeUid),
    { status: "refunded" satisfies AffiliateAttributionStatus },
    { merge: true }
  );

  if (clawed > 0) await batch.commit();
  return { clawed };
}

export async function markAffiliateAttributionChurned(
  inviteeUid: string
): Promise<void> {
  const attribution = await getAffiliateAttributionForUser(inviteeUid);
  if (!attribution) return;

  const now = admin.firestore.Timestamp.now();
  await db()
    .collection("users")
    .doc(inviteeUid)
    .collection("affiliateMeta")
    .doc("referredBy")
    .set({ status: "churned" satisfies AffiliateAttributionStatus }, { merge: true });

  await db()
    .collection("affiliates")
    .doc(attribution.affiliateId)
    .collection("attributions")
    .doc(inviteeUid)
    .set({ status: "churned" satisfies AffiliateAttributionStatus }, { merge: true });

  await db()
    .collection("affiliates")
    .doc(attribution.affiliateId)
    .set(
      {
        "stats.activeSubscribers": admin.firestore.FieldValue.increment(-1),
        updatedAt: now,
      },
      { merge: true }
    );
}

export async function releaseDueAffiliateCommissions(
  affiliateId?: string
): Promise<number> {
  const now = admin.firestore.Timestamp.now();
  let query = db()
    .collection("affiliateCommissions")
    .where("status", "==", "pending_hold")
    .where("holdUntil", "<=", now)
    .limit(200);

  if (affiliateId) {
    query = query.where("affiliateId", "==", affiliateId);
  }

  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  let released = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data() as AffiliateCommissionDoc;
    await db().runTransaction(async (transaction) => {
      const fresh = await transaction.get(doc.ref);
      if (!fresh.exists) return;
      const current = fresh.data() as AffiliateCommissionDoc;
      if (current.status !== "pending_hold") return;
      if (current.holdUntil.toMillis() > now.toMillis()) return;

      transaction.set(
        doc.ref,
        {
          status: "payable" satisfies AffiliateCommissionStatus,
          payableAt: now,
        },
        { merge: true }
      );

      transaction.set(
        db().collection("affiliates").doc(current.affiliateId),
        {
          "stats.pendingCents": admin.firestore.FieldValue.increment(-current.commissionCents),
          "stats.payableCents": admin.firestore.FieldValue.increment(current.commissionCents),
          updatedAt: now,
        },
        { merge: true }
      );
    });
    released += 1;
  }

  return released;
}

export async function readOwnedProcessReferralCode(uid: string): Promise<string | null> {
  const program = await db()
    .collection("users")
    .doc(uid)
    .collection("referralMeta")
    .doc("program")
    .get();
  const raw = program.data()?.referralCode;
  if (typeof raw !== "string") return null;
  const normalized = normalizeReferralCode(raw);
  if (!isValidReferralCode(normalized)) return null;
  const owner = await resolveReferrerUserId(normalized);
  return owner === uid ? normalized : null;
}

export function pickPrimaryAffiliateCode(
  codes: string[],
  stored?: string,
  processCode?: string | null
): string {
  if (processCode && codes.includes(processCode)) return processCode;
  if (stored && codes.includes(stored)) return stored;
  const processLike = codes.find((code) => code.length === 5);
  if (processLike) return processLike;
  return codes[0] || "";
}

export async function ensureAffiliateProfile(params: {
  affiliateId: string;
  displayName: string;
  email?: string;
  uid?: string;
  status?: AffiliateStatus;
}): Promise<{ affiliateId: string }> {
  const affiliateId = params.affiliateId.trim();
  if (!affiliateId) throw new Error("INVALID_CODE");

  const affiliateRef = db().collection("affiliates").doc(affiliateId);
  const now = admin.firestore.Timestamp.now();
  const existing = await affiliateRef.get();
  if (existing.exists) {
    await affiliateRef.set(
      {
        displayName: params.displayName.slice(0, 80),
        ...(params.email ? { email: params.email.slice(0, 120) } : {}),
        updatedAt: now,
      },
      { merge: true }
    );
    return { affiliateId };
  }

  await affiliateRef.set({
    uid: params.uid ?? null,
    displayName: params.displayName.slice(0, 80),
    email: params.email?.slice(0, 120) ?? null,
    status: params.status ?? "active",
    codes: [],
    stats: {
      referredCount: 0,
      activeSubscribers: 0,
      pendingCents: 0,
      payableCents: 0,
      paidCents: 0,
      lifetimeCents: 0,
    },
    createdAt: now,
    updatedAt: now,
  });
  return { affiliateId };
}

export async function createAffiliateWithCode(params: {
  affiliateId: string;
  code: string;
  displayName: string;
  email?: string;
  uid?: string;
  status?: AffiliateStatus;
  commissionRate?: number;
  makePrimary?: boolean;
}): Promise<{ affiliateId: string; code: string }> {
  const code = normalizeAffiliateCode(params.code);
  if (!code || code.length < 3) throw new Error("INVALID_CODE");

  const affiliateId = params.affiliateId.trim();
  if (!affiliateId) throw new Error("INVALID_CODE");

  const now = admin.firestore.Timestamp.now();
  const commissionRate = params.commissionRate ?? AFFILIATE_COMMISSION_RATE;
  const status = params.status ?? "active";

  const affiliateRef = db().collection("affiliates").doc(affiliateId);
  const codeRef = db().collection("affiliateCodes").doc(code);

  await db().runTransaction(async (transaction) => {
    const existingCode = await transaction.get(codeRef);
    if (existingCode.exists) {
      const owner = existingCode.data()?.affiliateId;
      if (owner && owner !== affiliateId) throw new Error("CODE_CONFLICT");
    }

    const affiliateSnap = await transaction.get(affiliateRef);
    const currentCodes = Array.isArray(affiliateSnap.data()?.codes)
      ? (affiliateSnap.data()?.codes as string[])
      : [];
    const nextCodes = params.makePrimary
      ? [code, ...currentCodes.filter((item) => item !== code)]
      : currentCodes.includes(code)
        ? currentCodes
        : [...currentCodes, code];
    const nextPrimary =
      params.makePrimary || !affiliateSnap.data()?.primaryCode
        ? code
        : String(affiliateSnap.data()?.primaryCode || code);

    transaction.set(
      codeRef,
      {
        affiliateId,
        affiliateCode: code,
        displayName: params.displayName.slice(0, 80),
        status,
        commissionRate,
        createdAt: now,
        updatedAt: now,
      } satisfies AffiliateCodeDoc,
      { merge: true }
    );

    transaction.set(
      affiliateRef,
      {
        uid: params.uid ?? null,
        displayName: params.displayName.slice(0, 80),
        email: params.email?.slice(0, 120) ?? affiliateSnap.data()?.email ?? null,
        status,
        codes: nextCodes,
        primaryCode: nextPrimary,
        ...(affiliateSnap.exists
          ? {}
          : {
              stats: {
                referredCount: 0,
                activeSubscribers: 0,
                pendingCents: 0,
                payableCents: 0,
                paidCents: 0,
                lifetimeCents: 0,
              },
            }),
        createdAt: affiliateSnap.data()?.createdAt ?? now,
        updatedAt: now,
      },
      { merge: true }
    );
  });

  return { affiliateId, code };
}

export async function ensureEmailPasswordSignInEnabled(): Promise<void> {
  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  if (!projectId) return;

  try {
    const { GoogleAuth } = await import("google-auth-library");
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
    const client = await auth.getClient();
    const accessToken = await client.getAccessToken();
    const token = accessToken.token;
    if (!token) return;

    const url = `https://identitytoolkit.googleapis.com/v2/projects/${projectId}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired,signIn.anonymous.enabled`;
    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        signIn: {
          email: {
            enabled: true,
            passwordRequired: false,
          },
          anonymous: {
            enabled: true,
          },
        },
      }),
    });
    if (!response.ok) {
      const text = await response.text();
      console.warn("[ensureEmailPasswordSignInEnabled]", response.status, text);
    }
  } catch (error) {
    console.warn("[ensureEmailPasswordSignInEnabled]", error);
  }
}

export async function provisionAffiliateAuthUser(params: {
  email: string;
  password: string;
  displayName?: string;
}): Promise<string> {
  const email = params.email.trim().toLowerCase();
  const password = params.password;
  if (!email || !password || password.length < 8) {
    throw new Error("INVALID_AUTH");
  }

  await ensureEmailPasswordSignInEnabled();

  try {
    const created = await admin.auth().createUser({
      email,
      password,
      displayName: params.displayName?.slice(0, 80),
      emailVerified: true,
    });
    return created.uid;
  } catch (error: any) {
    if (error?.code === "auth/email-already-exists") {
      const existing = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(existing.uid, {
        password,
        displayName: params.displayName?.slice(0, 80) || existing.displayName,
      });
      return existing.uid;
    }
    throw error;
  }
}

export async function linkAffiliateAuthUser(params: {
  affiliateId: string;
  email: string;
  password: string;
  displayName?: string;
}): Promise<{ uid: string; affiliateId: string; email: string }> {
  const affiliateId = params.affiliateId.trim();
  if (!affiliateId) throw new Error("NOT_FOUND");

  const ref = db().collection("affiliates").doc(affiliateId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error("NOT_FOUND");

  const email = params.email.trim().toLowerCase();
  const uid = await provisionAffiliateAuthUser({
    email,
    password: params.password,
    displayName: params.displayName || snap.data()?.displayName,
  });

  await ref.set(
    {
      uid,
      email: email.slice(0, 120),
      updatedAt: admin.firestore.Timestamp.now(),
    },
    { merge: true }
  );

  return { uid, affiliateId, email };
}

export function verifyAffiliateAdmin(req: any, expectedSecret: string): void {
  const expected = expectedSecret.trim();
  if (!expected) throw new Error("INVALID_ADMIN");
  const header = String(req.headers["x-affiliate-admin-secret"] ?? "").trim();
  if (!header || header !== expected) throw new Error("INVALID_ADMIN");
}

export async function getAffiliateForUid(
  uid: string
): Promise<(AffiliateDoc & { affiliateId: string }) | null> {
  const snapshot = await db()
    .collection("affiliates")
    .where("uid", "==", uid)
    .limit(1)
    .get();

  if (snapshot.empty) return null;
  const doc = snapshot.docs[0];
  return { affiliateId: doc.id, ...(doc.data() as AffiliateDoc) };
}

export function formatMoney(cents: number, currency = "EUR"): string {
  const amount = cents / 100;
  try {
    return new Intl.NumberFormat("fr-FR", {
      style: "currency",
      currency,
      maximumFractionDigits: 2,
    }).format(amount);
  } catch {
    return `${amount.toFixed(2)} ${currency}`;
  }
}
