import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import {
  db,
  httpStatusForError,
  normalizeReferralCode,
  isValidReferralCode,
  isReservedLifetimePassCode,
  registerReferralRecord,
  resolveReferrerUserId,
  setCors,
  upsertReferralCode,
  verifyAppAttestation,
  verifyFirebaseUser,
} from "./referralShared";

export const referralSyncProgram = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const uid = await verifyFirebaseUser(req);
      await verifyAppAttestation(req);

      const referralCode = normalizeReferralCode(String(req.body?.referralCode ?? ""));
      const displayName = String(req.body?.displayName ?? "").trim();
      if (!isValidReferralCode(referralCode) || isReservedLifetimePassCode(referralCode)) {
        res.status(400).json({ error: "INVALID_CODE" });
        return;
      }

      await upsertReferralCode({
        userId: uid,
        referralCode,
        displayName: displayName || "Member",
      });

      res.status(200).json({ ok: true, referralCode });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[referralSyncProgram]", message);
      res.status(httpStatusForError(message)).json({ error: message });
    }
  }
);

export const referralRegister = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const uid = await verifyFirebaseUser(req);
      await verifyAppAttestation(req);

      const referralCode = normalizeReferralCode(String(req.body?.referralCode ?? ""));
      const displayName = String(req.body?.displayName ?? "").trim();
      if (!isValidReferralCode(referralCode) || isReservedLifetimePassCode(referralCode)) {
        res.status(400).json({ error: "INVALID_CODE" });
        return;
      }

      const referrerUserId = await resolveReferrerUserId(referralCode);
      if (!referrerUserId) {
        res.status(404).json({ error: "REFERRER_NOT_FOUND" });
        return;
      }

      await registerReferralRecord({
        referrerUserId,
        referredUserId: uid,
        referralCode,
        referredDisplayName: displayName || "Member",
      });

      await db()
        .collection("users")
        .doc(referrerUserId)
        .collection("referralMeta")
        .doc("program")
        .set(
          {
            pendingCount: admin.firestore.FieldValue.increment(1),
          },
          { merge: true }
        );

      res.status(200).json({ ok: true, referralCode, referrerUserId });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[referralRegister]", message);
      res.status(httpStatusForError(message)).json({ error: message });
    }
  }
);

export const referralDashboard = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 45,
    memory: "512MiB",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const uid = await verifyFirebaseUser(req);
      await verifyAppAttestation(req);

      const { fetchReferralProgramDashboard } = await import("./referralShared");
      const dashboard = await fetchReferralProgramDashboard(uid);
      res.status(200).json(dashboard);
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[referralDashboard]", message);
      res.status(httpStatusForError(message)).json({ error: message });
    }
  }
);
