import * as admin from "firebase-admin";
import { createHash, randomBytes } from "node:crypto";

const HANDOFF_COLLECTION = "affiliatePortalHandoffs";

/** Short window: the app opens the portal immediately after asking for the code. */
export const HANDOFF_TTL_MS = 5 * 60 * 1000;

function db(): admin.firestore.Firestore {
  return admin.firestore();
}

/** Only the hash is stored — a Firestore leak must not hand out portal sessions. */
function handoffDocId(code: string): string {
  return createHash("sha256").update(code).digest("hex");
}

/**
 * One-time code the iOS app passes to the web portal instead of an email link.
 * Clippers signed in with Apple "Hide My Email" can never receive that email,
 * so the app hands off its own session rather than routing through SMTP.
 */
export async function createPortalHandoff(
  uid: string
): Promise<{ code: string; expiresAt: number }> {
  if (!uid) throw new Error("UNAUTHORIZED");

  const code = randomBytes(32).toString("base64url");
  const expiresAtMs = Date.now() + HANDOFF_TTL_MS;

  await db()
    .collection(HANDOFF_COLLECTION)
    .doc(handoffDocId(code))
    .set({
      uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMs),
      usedAt: null,
    });

  void sweepExpiredHandoffs();

  return { code, expiresAt: expiresAtMs };
}

/** Redeems a code exactly once and returns a custom token for signInWithCustomToken. */
export async function redeemPortalHandoff(rawCode: string): Promise<string> {
  const code = String(rawCode || "").trim();
  if (!code) throw new Error("HANDOFF_INVALID");

  const ref = db().collection(HANDOFF_COLLECTION).doc(handoffDocId(code));

  const uid = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error("HANDOFF_INVALID");

    const data = snap.data() as {
      uid?: string;
      usedAt?: unknown;
      expiresAt?: admin.firestore.Timestamp;
    };

    if (data.usedAt) throw new Error("HANDOFF_INVALID");
    if (!data.uid) throw new Error("HANDOFF_INVALID");

    const expiresAtMs = data.expiresAt?.toMillis?.() ?? 0;
    if (!expiresAtMs || expiresAtMs < Date.now()) throw new Error("HANDOFF_EXPIRED");

    tx.update(ref, { usedAt: admin.firestore.FieldValue.serverTimestamp() });
    return data.uid;
  });

  return admin.auth().createCustomToken(uid);
}

/** Best-effort GC so redeemed/expired codes don't pile up. Never blocks a request. */
async function sweepExpiredHandoffs(): Promise<void> {
  try {
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - HANDOFF_TTL_MS);
    const stale = await db()
      .collection(HANDOFF_COLLECTION)
      .where("expiresAt", "<", cutoff)
      .limit(20)
      .get();
    if (stale.empty) return;

    const batch = db().batch();
    stale.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  } catch (error) {
    console.warn("[affiliatePortalHandoff] sweep failed", error);
  }
}
