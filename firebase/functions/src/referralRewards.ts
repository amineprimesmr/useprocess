import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import {
  accrueReferralCommission,
  clawbackReferralCommission,
  markReferralAttributionChurned,
} from "./referralCommissions";
import { httpStatusForError, setCors, verifyAppAttestation, verifyFirebaseUser } from "./referralShared";

const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

export const referralConfirmSubscription = onRequest(
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
      await verifyFirebaseUser(req);
      await verifyAppAttestation(req);
      // Commissions are credited by the RevenueCat webhook on paid events.
      res.status(200).json({ ok: true, skipped: "WEBHOOK_PRIMARY" });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[referralConfirmSubscription]", message);
      res.status(httpStatusForError(message)).json({ error: message });
    }
  }
);

export const referralRevenueCatWebhook = onRequest(
  {
    invoker: "public",
    cors: false,
    secrets: [revenueCatWebhookSecret],
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const authHeader = String(req.headers.authorization ?? "");
      const expected = `Bearer ${revenueCatWebhookSecret.value()}`;
      if (authHeader !== expected) {
        res.status(401).json({ error: "UNAUTHORIZED" });
        return;
      }

      const event = req.body?.event;
      const eventType = String(event?.type ?? "");
      const appUserId = String(event?.app_user_id ?? "").trim();

      if (!appUserId) {
        res.status(200).json({ ok: true, skipped: "NO_APP_USER_ID" });
        return;
      }

      if (eventType === "REFUND") {
        const result = await clawbackReferralCommission({ inviteeUid: appUserId, event });
        res.status(200).json({ ok: true, clawed: result.clawed });
        return;
      }

      if (eventType === "CANCELLATION" || eventType === "EXPIRATION") {
        await markReferralAttributionChurned(appUserId);
        res.status(200).json({ ok: true, status: eventType });
        return;
      }

      const result = await accrueReferralCommission({ inviteeUid: appUserId, event });
      res.status(200).json({ ok: true, ...result });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[referralRevenueCatWebhook]", message);
      res.status(500).json({ error: message });
    }
  }
);
