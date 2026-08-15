import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { isPaidPurchaseEvent } from "./revenueCat";
import {
  httpStatusForError,
  processReferralRewards,
  setCors,
  verifyAppAttestation,
  verifyFirebaseUser,
} from "./referralShared";

const revenueCatSecretKey = defineSecret("REVENUECAT_SECRET_API_KEY");
const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

export const referralConfirmSubscription = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [revenueCatSecretKey],
    timeoutSeconds: 60,
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

      const rewards = await processReferralRewards({
        referredUserId: uid,
        secretKey: revenueCatSecretKey.value(),
      });

      res.status(200).json({ ok: true, rewards });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      if (
        message === "NOT_REFERRED" ||
        message === "ALREADY_REWARDED" ||
        message === "SUBSCRIPTION_REQUIRED"
      ) {
        res.status(200).json({ ok: true, skipped: message });
        return;
      }
      console.error("[referralConfirmSubscription]", message);
      res.status(httpStatusForError(message)).json({ error: message });
    }
  }
);

export const referralRevenueCatWebhook = onRequest(
  {
    invoker: "public",
    cors: false,
    secrets: [revenueCatSecretKey, revenueCatWebhookSecret],
    timeoutSeconds: 60,
    memory: "256MiB",
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
      const eventType = event?.type as string | undefined;
      const appUserId = event?.app_user_id as string | undefined;

      if (!appUserId) {
        res.status(200).json({ ok: true, skipped: "NO_APP_USER_ID" });
        return;
      }

      const isInitialPaid =
        eventType === "INITIAL_PURCHASE" && isPaidPurchaseEvent(event);
      const isLifetime = eventType === "NON_RENEWING_PURCHASE";
      const isTrialConversion =
        eventType === "RENEWAL" && event?.is_trial_conversion === true;

      if (!isInitialPaid && !isLifetime && !isTrialConversion) {
        res.status(200).json({ ok: true, skipped: eventType ?? "UNKNOWN_EVENT" });
        return;
      }

      const rewards = await processReferralRewards({
        referredUserId: appUserId,
        secretKey: revenueCatSecretKey.value(),
      });

      res.status(200).json({ ok: true, rewards });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      if (
        message === "NOT_REFERRED" ||
        message === "ALREADY_REWARDED" ||
        message === "SUBSCRIPTION_REQUIRED"
      ) {
        res.status(200).json({ ok: true, skipped: message });
        return;
      }
      console.error("[referralRevenueCatWebhook]", message);
      res.status(500).json({ error: message });
    }
  }
);
