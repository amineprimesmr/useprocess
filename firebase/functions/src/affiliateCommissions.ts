import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import {
  accrueAffiliateCommission,
  clawbackAffiliateCommission,
  markAffiliateAttributionChurned,
  verifyAffiliateAdmin,
} from "./affiliateShared";
import { setCors } from "./referralShared";

const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");
const affiliateAdminSecret = defineSecret("AFFILIATE_ADMIN_SECRET");

export const affiliateRevenueCatWebhook = onRequest(
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
        const result = await clawbackAffiliateCommission({
          inviteeUid: appUserId,
          event,
        });
        res.status(200).json({ ok: true, clawed: result.clawed });
        return;
      }

      if (eventType === "CANCELLATION" || eventType === "EXPIRATION") {
        await markAffiliateAttributionChurned(appUserId);
        res.status(200).json({ ok: true, status: eventType });
        return;
      }

      const result = await accrueAffiliateCommission({
        inviteeUid: appUserId,
        event,
      });

      res.status(200).json({ ok: true, ...result });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateRevenueCatWebhook]", message);
      res.status(500).json({ error: message });
    }
  }
);

export const affiliateReleaseHeldCommissions = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
    timeoutSeconds: 120,
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
      const { releaseDueAffiliateCommissions } = await import("./affiliateShared");
      verifyAffiliateAdmin(req, affiliateAdminSecret.value());
      const affiliateId = String(req.body?.affiliateId ?? "").trim() || undefined;
      const released = await releaseDueAffiliateCommissions(affiliateId);
      res.status(200).json({ ok: true, released });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateReleaseHeldCommissions]", message);
      res.status(500).json({ error: message });
    }
  }
);
