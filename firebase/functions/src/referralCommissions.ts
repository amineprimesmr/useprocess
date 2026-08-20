import * as admin from "firebase-admin";
import { isPaidPurchaseEvent } from "./revenueCat";
import {
  COMMISSION_HOLD_DAYS,
  COMMISSION_RATE,
  commissionDocId,
  commissionFromRevenueCatEvent,
  type CommissionStatus,
} from "./commissionShared";
import { db, type ReferralStatus } from "./referralShared";

export interface ReferralCommissionDoc {
  referrerUserId: string;
  inviteeUid: string;
  referralCode: string;
  rcEventId: string;
  rcEventType: string;
  productId?: string;
  grossCents: number;
  netCents: number;
  commissionCents: number;
  commissionRate: number;
  currency: string;
  status: CommissionStatus;
  holdUntil: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
  payableAt?: admin.firestore.Timestamp;
  paidAt?: admin.firestore.Timestamp;
  payoutId?: string;
  clawedBackAt?: admin.firestore.Timestamp;
}

export type ReferralAttributionStatus = "pending" | "active" | "churned" | "refunded";

export async function getReferralAttributionForUser(
  inviteeUid: string
): Promise<
  | {
      referrerUserId: string;
      referralCode: string;
      status: ReferralAttributionStatus;
    }
  | null
> {
  const snap = await db()
    .collection("users")
    .doc(inviteeUid)
    .collection("referralMeta")
    .doc("referredBy")
    .get();

  if (!snap.exists) return null;
  const data = snap.data() ?? {};
  const referrerUserId = data.referrerUserId as string | undefined;
  const referralCode = data.referralCode as string | undefined;
  const rawStatus = data.status as string | undefined;

  if (!referrerUserId || !referralCode) return null;
  if (rawStatus === "refunded") return null;

  let status: ReferralAttributionStatus = "pending";
  if (rawStatus === "accepted" || rawStatus === "active") status = "active";
  else if (rawStatus === "churned") status = "churned";

  return { referrerUserId, referralCode, status };
}

async function markReferralInviteAccepted(params: {
  referrerUserId: string;
  inviteeUid: string;
}): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const referredMetaRef = db()
    .collection("users")
    .doc(params.inviteeUid)
    .collection("referralMeta")
    .doc("referredBy");
  const inviteRef = db()
    .collection("users")
    .doc(params.referrerUserId)
    .collection("referralInvites")
    .doc(params.inviteeUid);
  const programRef = db()
    .collection("users")
    .doc(params.referrerUserId)
    .collection("referralMeta")
    .doc("program");

  await db().runTransaction(async (transaction) => {
    const referredMeta = await transaction.get(referredMetaRef);
    const wasPending =
      !referredMeta.exists ||
      referredMeta.data()?.status === "pending" ||
      referredMeta.data()?.status === "processing";

    const acceptedPayload = {
      status: "accepted" as ReferralStatus,
      acceptedAt: now,
    };

    transaction.set(referredMetaRef, acceptedPayload, { merge: true });
    transaction.set(inviteRef, acceptedPayload, { merge: true });

    if (wasPending) {
      transaction.set(
        programRef,
        {
          acceptedCount: admin.firestore.FieldValue.increment(1),
          pendingCount: admin.firestore.FieldValue.increment(-1),
          "stats.activeSubscribers": admin.firestore.FieldValue.increment(1),
          lastCommissionAt: now,
        },
        { merge: true }
      );
    } else {
      transaction.set(
        programRef,
        { lastCommissionAt: now },
        { merge: true }
      );
    }
  });
}

export async function accrueReferralCommission(params: {
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

  const attribution = await getReferralAttributionForUser(params.inviteeUid);
  if (!attribution || attribution.status === "churned" || attribution.status === "refunded") {
    return { created: false, skipped: "NOT_REFERRED" };
  }

  const amounts = commissionFromRevenueCatEvent(params.event);
  if (!amounts) return { created: false, skipped: "NO_COMMISSION" };

  const commissionId = commissionDocId(attribution.referrerUserId, rcEventId);
  const commissionRef = db().collection("referralCommissions").doc(commissionId);
  const programRef = db()
    .collection("users")
    .doc(attribution.referrerUserId)
    .collection("referralMeta")
    .doc("program");

  const existing = await commissionRef.get();
  if (existing.exists) return { created: false, skipped: "DUPLICATE" };

  const now = admin.firestore.Timestamp.now();
  const holdUntil = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + COMMISSION_HOLD_DAYS * 86_400_000
  );

  const commission: ReferralCommissionDoc = {
    referrerUserId: attribution.referrerUserId,
    inviteeUid: params.inviteeUid,
    referralCode: attribution.referralCode,
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
      programRef,
      {
        "stats.pendingCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
        "stats.lifetimeCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
        updatedAt: now,
      },
      { merge: true }
    );
  });

  await markReferralInviteAccepted({
    referrerUserId: attribution.referrerUserId,
    inviteeUid: params.inviteeUid,
  });

  return { created: true, commissionId };
}

export async function clawbackReferralCommission(params: {
  inviteeUid: string;
  event: any;
}): Promise<{ clawed: number }> {
  const attribution = await getReferralAttributionForUser(params.inviteeUid);
  if (!attribution) return { clawed: 0 };

  const originalTransactionId = String(
    params.event?.original_transaction_id ??
      params.event?.transaction_id ??
      params.event?.id ??
      ""
  );
  if (!originalTransactionId) return { clawed: 0 };

  const commissions = await db()
    .collection("referralCommissions")
    .where("referrerUserId", "==", attribution.referrerUserId)
    .where("inviteeUid", "==", params.inviteeUid)
    .limit(50)
    .get();

  let clawed = 0;
  const batch = db().batch();
  const now = admin.firestore.Timestamp.now();
  const programRef = db()
    .collection("users")
    .doc(attribution.referrerUserId)
    .collection("referralMeta")
    .doc("program");

  for (const doc of commissions.docs) {
    const data = doc.data() as ReferralCommissionDoc;
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
      { status: "clawed_back", clawedBackAt: now },
      { merge: true }
    );

    const statField = data.status === "payable" ? "payableCents" : "pendingCents";
    batch.set(
      programRef,
      {
        [`stats.${statField}`]: admin.firestore.FieldValue.increment(-data.commissionCents),
        "stats.lifetimeCents": admin.firestore.FieldValue.increment(-data.commissionCents),
        updatedAt: now,
      },
      { merge: true }
    );
  }

  batch.set(
    db().collection("users").doc(params.inviteeUid).collection("referralMeta").doc("referredBy"),
    { status: "refunded" },
    { merge: true }
  );

  if (clawed > 0) await batch.commit();
  return { clawed };
}

export async function markReferralAttributionChurned(inviteeUid: string): Promise<void> {
  const attribution = await getReferralAttributionForUser(inviteeUid);
  if (!attribution) return;

  const now = admin.firestore.Timestamp.now();
  await db()
    .collection("users")
    .doc(inviteeUid)
    .collection("referralMeta")
    .doc("referredBy")
    .set({ status: "churned" }, { merge: true });

  await db()
    .collection("users")
    .doc(attribution.referrerUserId)
    .collection("referralMeta")
    .doc("program")
    .set(
      {
        "stats.activeSubscribers": admin.firestore.FieldValue.increment(-1),
        updatedAt: now,
      },
      { merge: true }
    );
}

export async function releaseDueReferralCommissions(
  referrerUserId?: string
): Promise<number> {
  const now = admin.firestore.Timestamp.now();
  let query = db()
    .collection("referralCommissions")
    .where("status", "==", "pending_hold")
    .where("holdUntil", "<=", now)
    .limit(200);

  if (referrerUserId) {
    query = query.where("referrerUserId", "==", referrerUserId);
  }

  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  let released = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data() as ReferralCommissionDoc;
    await db().runTransaction(async (transaction) => {
      const fresh = await transaction.get(doc.ref);
      if (!fresh.exists) return;
      const current = fresh.data() as ReferralCommissionDoc;
      if (current.status !== "pending_hold") return;
      if (current.holdUntil.toMillis() > now.toMillis()) return;

      transaction.set(doc.ref, { status: "payable", payableAt: now }, { merge: true });

      const programRef = db()
        .collection("users")
        .doc(current.referrerUserId)
        .collection("referralMeta")
        .doc("program");

      transaction.set(
        programRef,
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

export async function fetchReferralDashboard(uid: string): Promise<Record<string, unknown>> {
  await releaseDueReferralCommissions(uid);

  const programSnap = await db()
    .collection("users")
    .doc(uid)
    .collection("referralMeta")
    .doc("program")
    .get();

  const program = programSnap.data() ?? {};
  const stats = (program.stats as Record<string, number> | undefined) ?? {};

  const commissionsSnap = await db()
    .collection("referralCommissions")
    .where("referrerUserId", "==", uid)
    .limit(50)
    .get();

  const recentCommissions = commissionsSnap.docs
    .map((doc) => {
      const row = doc.data() as ReferralCommissionDoc;
      return {
        id: doc.id,
        inviteeUid: row.inviteeUid,
        eventType: row.rcEventType,
        productId: row.productId ?? null,
        commissionCents: row.commissionCents ?? 0,
        currency: row.currency ?? "EUR",
        status: row.status,
        createdAt: row.createdAt?.toMillis?.() ?? null,
        holdUntil: row.holdUntil?.toMillis?.() ?? null,
      };
    })
    .sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0))
    .slice(0, 25);

  return {
    ok: true,
    referralCode: program.referralCode ?? null,
    displayName: program.displayName ?? null,
    pendingCount: program.pendingCount ?? 0,
    acceptedCount: program.acceptedCount ?? 0,
    stats: {
      activeSubscribers: stats.activeSubscribers ?? 0,
      pendingCents: stats.pendingCents ?? 0,
      payableCents: stats.payableCents ?? 0,
      paidCents: stats.paidCents ?? 0,
      lifetimeCents: stats.lifetimeCents ?? 0,
    },
    commissionRate: COMMISSION_RATE,
    holdDays: COMMISSION_HOLD_DAYS,
    recentCommissions,
  };
}
