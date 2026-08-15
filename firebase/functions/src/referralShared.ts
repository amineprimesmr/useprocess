import * as admin from "firebase-admin";
import {
  activePremiumProductId,
  fetchSubscriber,
  grantPromotionalEntitlement,
  hasPaidPremium,
  isAnnualProduct,
  type RevenueCatDuration,
} from "./revenueCat";

export const PREMIUM_ENTITLEMENT = "premium";
export const REFERRER_REWARD_SHORT: RevenueCatDuration = "monthly";
export const REFERRER_REWARD_ANNUAL: RevenueCatDuration = "yearly";

export type ReferralStatus = "pending" | "accepted";

export interface ReferralInviteDoc {
  referredUserId: string;
  referralCode: string;
  displayName: string;
  invitedAt: admin.firestore.Timestamp;
  status: ReferralStatus;
  acceptedAt?: admin.firestore.Timestamp;
  inviteeRewardDuration?: RevenueCatDuration | null;
  referrerRewardDuration?: RevenueCatDuration;
}

export function db() {
  return admin.firestore();
}

export function normalizeReferralCode(raw: string): string {
  const cleaned = raw.trim().toUpperCase().replace(/\s+/g, "");
  if (!cleaned) return cleaned;
  if (cleaned.includes("-")) {
    return cleaned.replace(/[^A-Z0-9-]/g, "");
  }
  const alnum = cleaned.replace(/[^A-Z0-9]/g, "");
  if (alnum.length <= 4) return alnum;
  return `${alnum.slice(0, 4)}-${alnum.slice(4)}`;
}

export function setCors(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization, X-Firebase-AppCheck"
  );
}

export async function verifyFirebaseUser(req: any): Promise<string> {
  const header = req.headers.authorization as string | undefined;
  if (!header?.startsWith("Bearer ")) {
    throw new Error("UNAUTHORIZED");
  }
  const token = header.slice("Bearer ".length);
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded.uid;
}

export async function verifyAppAttestation(req: any): Promise<void> {
  const enforceAppCheck = process.env.ENFORCE_APP_CHECK === "true";
  const token = req.header("X-Firebase-AppCheck") as string | undefined;
  if (!token) {
    if (enforceAppCheck) throw new Error("INVALID_APP_CHECK");
    return;
  }
  try {
    await admin.appCheck().verifyToken(token);
  } catch (error) {
    if (enforceAppCheck) throw new Error("INVALID_APP_CHECK");
    console.warn("[AppCheck] Invalid token (monitoring mode)", error);
  }
}

export function httpStatusForError(message: string): number {
  if (message === "UNAUTHORIZED") return 401;
  if (message === "INVALID_APP_CHECK") return 401;
  if (message === "INVALID_CODE") return 400;
  if (message === "SELF_REFERRAL") return 400;
  if (message === "ALREADY_REFERRED") return 409;
  if (message === "NOT_REFERRED") return 404;
  if (message === "REFERRER_NOT_FOUND") return 404;
  if (message === "SUBSCRIPTION_REQUIRED") return 402;
  if (message === "ALREADY_REWARDED") return 409;
  if (message === "CODE_CONFLICT") return 409;
  return 500;
}

export async function resolveReferrerUserId(code: string): Promise<string | null> {
  const normalized = normalizeReferralCode(code);
  if (!normalized) return null;

  const snapshot = await db().collection("referralCodes").doc(normalized).get();
  if (!snapshot.exists) return null;
  const userId = snapshot.data()?.userId;
  return typeof userId === "string" && userId.length > 0 ? userId : null;
}

export async function upsertReferralCode(params: {
  userId: string;
  referralCode: string;
  displayName: string;
}): Promise<void> {
  const normalized = normalizeReferralCode(params.referralCode);
  if (!normalized) throw new Error("INVALID_CODE");

  const ref = db().collection("referralCodes").doc(normalized);
  await db().runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    if (existing.exists) {
      const owner = existing.data()?.userId;
      if (owner && owner !== params.userId) {
        throw new Error("CODE_CONFLICT");
      }
    }

    transaction.set(
      ref,
      {
        userId: params.userId,
        displayName: params.displayName.slice(0, 80),
        referralCode: normalized,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  await db()
    .collection("users")
    .doc(params.userId)
    .collection("referralMeta")
    .doc("program")
    .set(
      {
        referralCode: normalized,
        displayName: params.displayName.slice(0, 80),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

export async function registerReferralRecord(params: {
  referrerUserId: string;
  referredUserId: string;
  referralCode: string;
  referredDisplayName: string;
}): Promise<void> {
  if (params.referrerUserId === params.referredUserId) {
    throw new Error("SELF_REFERRAL");
  }

  const referredMetaRef = db()
    .collection("users")
    .doc(params.referredUserId)
    .collection("referralMeta")
    .doc("referredBy");

  const inviteRef = db()
    .collection("users")
    .doc(params.referrerUserId)
    .collection("referralInvites")
    .doc(params.referredUserId);

  await db().runTransaction(async (transaction) => {
    const existing = await transaction.get(referredMetaRef);
    if (existing.exists) {
      throw new Error("ALREADY_REFERRED");
    }

    const now = admin.firestore.Timestamp.now();
    const invite: ReferralInviteDoc = {
      referredUserId: params.referredUserId,
      referralCode: params.referralCode,
      displayName: params.referredDisplayName.slice(0, 80),
      invitedAt: now,
      status: "pending",
    };

    transaction.set(referredMetaRef, {
      referralCode: params.referralCode,
      referrerUserId: params.referrerUserId,
      registeredAt: now,
      status: "pending",
    });

    transaction.set(inviteRef, invite);
  });
}

async function referrerRewardDuration(
  referrerUserId: string,
  secretKey: string
): Promise<RevenueCatDuration> {
  try {
    const subscriber = await fetchSubscriber(referrerUserId, secretKey);
    const productId = activePremiumProductId(subscriber, PREMIUM_ENTITLEMENT);
    return isAnnualProduct(productId)
      ? REFERRER_REWARD_ANNUAL
      : REFERRER_REWARD_SHORT;
  } catch (error) {
    console.warn("[referral] Could not resolve referrer plan, defaulting to monthly", error);
    return REFERRER_REWARD_SHORT;
  }
}

async function claimReferralReward(referredUserId: string): Promise<{
  referrerUserId: string;
  referralCode: string;
  referredMetaRef: admin.firestore.DocumentReference;
}> {
  const referredMetaRef = db()
    .collection("users")
    .doc(referredUserId)
    .collection("referralMeta")
    .doc("referredBy");

  const claimed = await db().runTransaction(async (transaction) => {
    const referredMeta = await transaction.get(referredMetaRef);
    if (!referredMeta.exists) {
      throw new Error("NOT_REFERRED");
    }

    const meta = referredMeta.data() ?? {};
    if (meta.status === "accepted") {
      throw new Error("ALREADY_REWARDED");
    }
    if (meta.status === "processing") {
      const started = meta.processingAt?.toMillis?.() as number | undefined;
      if (started && Date.now() - started < 120_000) {
        throw new Error("ALREADY_REWARDED");
      }
    }

    const referrerUserId = meta.referrerUserId as string | undefined;
    const referralCode = meta.referralCode as string | undefined;
    if (!referrerUserId || !referralCode) {
      throw new Error("NOT_REFERRED");
    }

    transaction.set(
      referredMetaRef,
      {
        status: "processing",
        processingAt: admin.firestore.Timestamp.now(),
      },
      { merge: true }
    );

    return { referrerUserId, referralCode };
  });

  return { ...claimed, referredMetaRef };
}

async function revertReferralClaim(
  referredMetaRef: admin.firestore.DocumentReference
): Promise<void> {
  await referredMetaRef.set(
    {
      status: "pending",
      processingAt: admin.firestore.FieldValue.delete(),
    },
    { merge: true }
  );
}

export async function processReferralRewards(params: {
  referredUserId: string;
  secretKey: string;
}): Promise<{ referrerReward: RevenueCatDuration }> {
  const claim = await claimReferralReward(params.referredUserId);

  let referrerDuration: RevenueCatDuration;
  try {
    const subscriber = await fetchSubscriber(params.referredUserId, params.secretKey);
    if (!hasPaidPremium(subscriber, PREMIUM_ENTITLEMENT)) {
      throw new Error("SUBSCRIPTION_REQUIRED");
    }
    referrerDuration = await referrerRewardDuration(
      claim.referrerUserId,
      params.secretKey
    );
  } catch (error) {
    await revertReferralClaim(claim.referredMetaRef);
    throw error;
  }

  try {
    await grantPromotionalEntitlement(
      claim.referrerUserId,
      PREMIUM_ENTITLEMENT,
      referrerDuration,
      params.secretKey
    );
  } catch (error) {
    await revertReferralClaim(claim.referredMetaRef);
    throw error;
  }

  const now = admin.firestore.Timestamp.now();
  const inviteRef = db()
    .collection("users")
    .doc(claim.referrerUserId)
    .collection("referralInvites")
    .doc(params.referredUserId);
  const acceptedPayload = {
    status: "accepted" as const,
    acceptedAt: now,
    inviteeRewardDuration: null,
    referrerRewardDuration: referrerDuration,
  };

  try {
    await db().runTransaction(async (transaction) => {
      transaction.set(claim.referredMetaRef, acceptedPayload, { merge: true });
      transaction.set(inviteRef, acceptedPayload, { merge: true });
      transaction.set(
        db()
          .collection("users")
          .doc(claim.referrerUserId)
          .collection("referralMeta")
          .doc("program"),
        {
          acceptedCount: admin.firestore.FieldValue.increment(1),
          pendingCount: admin.firestore.FieldValue.increment(-1),
          lastRewardAt: now,
        },
        { merge: true }
      );
    });
  } catch (error) {
    console.error("[referral] granted referrer time but failed to persist", error);
    await claim.referredMetaRef.set(acceptedPayload, { merge: true });
    await inviteRef.set(acceptedPayload, { merge: true });
  }

  return { referrerReward: referrerDuration };
}
