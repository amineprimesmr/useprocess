import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import Stripe from "stripe";
import { affiliateHttpStatus, db, getAffiliateForUid } from "./affiliateShared";
import { setCors, verifyAppAttestation, verifyFirebaseUser } from "./referralShared";

const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_CONNECT_WEBHOOK_SECRET");

const AFFILIATE_PORTAL_BASE = "https://useprocess.xyz/affiliate";
const AFFILIATE_PRODUCT_DESCRIPTION =
  "Independent creator in the Process affiliate program. Promotes the Process iOS app on social media and earns a commission on subscriptions.";

function creatorPublicUrl(data: admin.firestore.DocumentData): string {
  const fromList = Array.isArray(data.onboarding?.tiktokHandles)
    ? data.onboarding.tiktokHandles
    : [];
  const fromSingle = String(data.onboarding?.tiktokHandle || "").split(/\s+/);
  const handle = String([...fromList, ...fromSingle].find(Boolean) || "")
    .trim()
    .replace(/^@+/, "");
  if (handle) return `https://www.tiktok.com/@${encodeURIComponent(handle)}`;
  const code = Array.isArray(data.codes) ? String(data.codes[0] || "") : "";
  if (code) return `https://useprocess.xyz/join/${encodeURIComponent(code)}`;
  return "https://useprocess.xyz";
}

function individualBusinessProfile(
  data: admin.firestore.DocumentData
): Stripe.AccountUpdateParams.BusinessProfile {
  return {
    mcc: "7311",
    product_description: AFFILIATE_PRODUCT_DESCRIPTION,
    url: creatorPublicUrl(data),
  };
}

function stripeClient(secret: string): Stripe {
  return new Stripe(secret);
}

function payoutReturnUrl(kind: "return" | "refresh"): string {
  return `${AFFILIATE_PORTAL_BASE}#/payouts?stripe=${kind}`;
}

export interface StripeConnectSnapshot {
  accountId: string | null;
  onboardingComplete: boolean;
  payoutsEnabled: boolean;
  detailsSubmitted: boolean;
  requirementsDue: string[];
}

export async function readStripeConnectSnapshot(
  accountId: string | null | undefined,
  secret: string
): Promise<StripeConnectSnapshot> {
  if (!accountId) {
    return {
      accountId: null,
      onboardingComplete: false,
      payoutsEnabled: false,
      detailsSubmitted: false,
      requirementsDue: [],
    };
  }

  const stripe = stripeClient(secret);
  const account = await stripe.accounts.retrieve(accountId);
  const requirementsDue = [
    ...(account.requirements?.currently_due ?? []),
    ...(account.requirements?.past_due ?? []),
  ];

  return {
    accountId,
    onboardingComplete: Boolean(account.details_submitted && account.payouts_enabled),
    payoutsEnabled: Boolean(account.payouts_enabled),
    detailsSubmitted: Boolean(account.details_submitted),
    requirementsDue,
  };
}

async function persistStripeSnapshot(
  affiliateId: string,
  snapshot: StripeConnectSnapshot
): Promise<void> {
  await db()
    .collection("affiliates")
    .doc(affiliateId)
    .set(
      {
        stripeAccountId: snapshot.accountId,
        stripeOnboardingComplete: snapshot.onboardingComplete,
        stripePayoutsEnabled: snapshot.payoutsEnabled,
        stripeDetailsSubmitted: snapshot.detailsSubmitted,
        stripeRequirementsDue: snapshot.requirementsDue,
        payoutMethod: "stripe",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

async function ensureExpressAccount(params: {
  affiliateId: string;
  uid: string;
  email?: string;
  displayName?: string;
  country?: string;
  secret: string;
}): Promise<string> {
  const affiliateRef = db().collection("affiliates").doc(params.affiliateId);
  const affiliateSnap = await affiliateRef.get();
  const data = affiliateSnap.data() ?? {};

  const stripe = stripeClient(params.secret);

  if (data.stripeAccountId) {
    return String(data.stripeAccountId);
  }

  const account = await stripe.accounts.create({
    type: "express",
    country: (params.country || "FR").toUpperCase().slice(0, 2),
    email: params.email || undefined,
    business_type: "individual",
    business_profile: individualBusinessProfile(data),
    capabilities: {
      transfers: { requested: true },
    },
    metadata: {
      affiliateId: params.affiliateId,
      uid: params.uid,
      displayName: (params.displayName || "").slice(0, 80),
    },
  });

  await affiliateRef.set(
    {
      stripeAccountId: account.id,
      payoutMethod: "stripe",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return account.id;
}

export async function createAffiliateStripeTransfer(params: {
  affiliateId: string;
  stripeAccountId: string;
  amountCents: number;
  currency: string;
  payoutId: string;
  secret: string;
}): Promise<string> {
  const stripe = stripeClient(params.secret);
  const transfer = await stripe.transfers.create({
    amount: params.amountCents,
    currency: params.currency.toLowerCase(),
    destination: params.stripeAccountId,
    metadata: {
      affiliateId: params.affiliateId,
      payoutId: params.payoutId,
    },
  });
  return transfer.id;
}

export const affiliateStripeConnectStart = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [stripeSecretKey],
    timeoutSeconds: 20,
    memory: "512MiB",
    minInstances: 1,
    concurrency: 40,
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

      const affiliate = await getAffiliateForUid(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }

      const secret = stripeSecretKey.value();
      const country = String(req.body?.country ?? "FR").trim() || "FR";
      const accountId =
        affiliate.stripeAccountId ||
        (await ensureExpressAccount({
          affiliateId: affiliate.affiliateId,
          uid,
          email: affiliate.email ?? undefined,
          displayName: affiliate.displayName,
          country,
          secret,
        }));

      const stripe = stripeClient(secret);
      const link = await stripe.accountLinks.create({
        account: accountId,
        type: "account_onboarding",
        refresh_url: payoutReturnUrl("refresh"),
        return_url: payoutReturnUrl("return"),
        collection_options: { fields: "currently_due" },
      });

      res.status(200).json({ ok: true, url: link.url, accountId });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateStripeConnectStart]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateStripeConnectSync = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [stripeSecretKey],
    timeoutSeconds: 20,
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

      const affiliate = await getAffiliateForUid(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }

      const accountId = affiliate.stripeAccountId;
      if (!accountId) {
        res.status(404).json({ error: "STRIPE_NOT_LINKED" });
        return;
      }

      const snapshot = await readStripeConnectSnapshot(accountId, stripeSecretKey.value());
      await persistStripeSnapshot(affiliate.affiliateId, snapshot);

      res.status(200).json({ ok: true, stripeConnect: snapshot });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateStripeConnectSync]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateStripeConnectDashboard = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [stripeSecretKey],
    timeoutSeconds: 20,
    memory: "512MiB",
    minInstances: 1,
    concurrency: 40,
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

      const affiliate = await getAffiliateForUid(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }

      const accountId = affiliate.stripeAccountId;
      if (!accountId) {
        res.status(404).json({ error: "STRIPE_NOT_LINKED" });
        return;
      }

      const stripe = stripeClient(stripeSecretKey.value());
      const loginLink = await stripe.accounts.createLoginLink(accountId);

      res.status(200).json({ ok: true, url: loginLink.url });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateStripeConnectDashboard]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateStripeWebhook = onRequest(
  {
    invoker: "public",
    cors: false,
    secrets: [stripeSecretKey, stripeWebhookSecret],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      const stripe = stripeClient(stripeSecretKey.value());
      const signature = req.headers["stripe-signature"];
      if (!signature || typeof signature !== "string") {
        res.status(400).send("Missing stripe-signature");
        return;
      }

      const event = stripe.webhooks.constructEvent(
        req.rawBody,
        signature,
        stripeWebhookSecret.value()
      );

      if (event.type === "account.updated") {
        const account = event.data.object as Stripe.Account;
        const affiliateId = account.metadata?.affiliateId;
        if (affiliateId) {
          const snapshot = await readStripeConnectSnapshot(account.id, stripeSecretKey.value());
          await persistStripeSnapshot(affiliateId, snapshot);
        }
      }

      res.status(200).json({ received: true });
    } catch (error: any) {
      console.error("[affiliateStripeWebhook]", error?.message ?? error);
      res.status(400).send(`Webhook error: ${error?.message ?? "unknown"}`);
    }
  }
);
