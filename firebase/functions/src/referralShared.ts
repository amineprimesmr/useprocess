import * as admin from "firebase-admin";

export const PREMIUM_ENTITLEMENT = "premium";

export type ReferralStatus = "pending" | "accepted";

export interface ReferralInviteDoc {
  referredUserId: string;
  referralCode: string;
  displayName: string;
  invitedAt: admin.firestore.Timestamp;
  status: ReferralStatus;
  acceptedAt?: admin.firestore.Timestamp;
}

export function db() {
  return admin.firestore();
}

export const REFERRAL_CODE_LENGTH = 5;

export function normalizeReferralCode(raw: string): string {
  const alnum = String(raw || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "")
    .replace(/[^A-Z0-9]/g, "");
  return alnum.slice(0, REFERRAL_CODE_LENGTH);
}

export function isValidReferralCode(raw: string): boolean {
  return normalizeReferralCode(raw).length === REFERRAL_CODE_LENGTH;
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
  if (message === "INVALID_TEXT") return 400;
  if (message === "RATE_LIMITED") return 429;
  if (message === "CRISP_UNAVAILABLE") return 503;
  return 500;
}

export async function resolveReferrerUserId(code: string): Promise<string | null> {
  const normalized = normalizeReferralCode(code);
  if (!isValidReferralCode(normalized)) return null;

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
  if (!isValidReferralCode(normalized)) throw new Error("INVALID_CODE");

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
        stats: {
          pendingCents: 0,
          payableCents: 0,
          paidCents: 0,
          lifetimeCents: 0,
          activeSubscribers: 0,
        },
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
