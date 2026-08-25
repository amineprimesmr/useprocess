import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import {
  affiliateHttpStatus,
  createAffiliateWithCode,
  allocateUniqueAffiliateCode,
  db,
  ensureAffiliateProfile,
  ensureEmailPasswordSignInEnabled,
  getAffiliateForUid,
  pickPrimaryAffiliateCode,
  readOwnedProcessReferralCode,
  updateAffiliateInviteProfile,
  linkAffiliateAuthUser,
  normalizeAffiliateCode,
  provisionAffiliateAuthUser,
  registerAffiliateAttribution,
  releaseDueAffiliateCommissions,
  resolveAffiliateByCode,
  resolveCodeKind,
  verifyAffiliateAdmin,
} from "./affiliateShared";
import {
  readAffiliateDailySeries,
  trackAffiliateLinkEvent,
  trackAffiliatePaywall,
} from "./affiliateFunnel";
import { emptyDailySeries } from "./affiliateAnalytics";
import {
  setCors,
  verifyAppAttestation,
  verifyFirebaseUser,
} from "./referralShared";
import { createAffiliateStripeTransfer } from "./affiliateStripe";
import { listPublicTikTokAccounts, tiktokApiReady, tiktokTotals } from "./affiliateTikTok";

const affiliateAdminSecret = defineSecret("AFFILIATE_ADMIN_SECRET");
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

function readAffiliateOnboarding(raw: unknown) {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  return {
    firstName: String(row.firstName ?? "").slice(0, 80),
    phone: String(row.phone ?? "").slice(0, 40),
    postedTiktok: String(row.postedTiktok ?? "").slice(0, 12),
    tiktokHandle: String(row.tiktokHandle ?? "").slice(0, 240),
    tiktokHandles: Array.isArray(row.tiktokHandles)
      ? row.tiktokHandles.map((value) => String(value ?? "").slice(0, 80)).filter(Boolean).slice(0, 8)
      : [],
    hoursPerDay: String(row.hoursPerDay ?? "").slice(0, 40),
    toolBudget: String(row.toolBudget ?? "").slice(0, 40),
    experience: String(row.experience ?? "").slice(0, 40),
    goal: String(row.goal ?? "").slice(0, 40),
  };
}

function isValidAffiliatePhone(raw: string): boolean {
  const digits = String(raw || "").replace(/\D/g, "");
  return digits.length >= 8 && digits.length <= 15;
}

export const affiliatePreparePasswordless = onRequest(
  {
    invoker: "public",
    cors: true,
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
      await ensureEmailPasswordSignInEnabled();
      res.status(200).json({ ok: true });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliatePreparePasswordless]", message);
      res.status(500).json({ error: message });
    }
  }
);

export const affiliateResolveCode = onRequest(
  {
    invoker: "public",
    cors: true,
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
      const code = String(req.body?.code ?? req.query?.code ?? "");
      const resolved = await resolveCodeKind(code);
      if (!resolved) {
        res.status(404).json({ error: "CODE_NOT_FOUND" });
        return;
      }
      res.status(200).json({ ok: true, ...resolved });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateResolveCode]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

function clientIp(req: any): string {
  const forwarded = String(req.headers?.["x-forwarded-for"] ?? "").split(",")[0].trim();
  return forwarded || String(req.ip || "").trim() || "unknown";
}

export const affiliateTrackLink = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 15,
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
      const event = String(req.body?.event ?? "view") === "store" ? "store" : "view";
      const result = await trackAffiliateLinkEvent({
        code: String(req.body?.code ?? ""),
        event,
        visitorId: String(req.body?.visitorId ?? ""),
        userAgent: String(req.headers["user-agent"] ?? ""),
        ip: clientIp(req),
      });
      res.status(200).json(result);
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateTrackLink]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateTrackFunnel = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 15,
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
      const event = String(req.body?.event ?? "");
      if (event !== "paywall") {
        res.status(400).json({ error: "INVALID_EVENT" });
        return;
      }

      let uid: string | null = null;
      try {
        uid = await verifyFirebaseUser(req);
      } catch {
        uid = null;
      }

      const result = await trackAffiliatePaywall({
        code: String(req.body?.code ?? ""),
        visitorId: String(req.body?.visitorId ?? ""),
        uid,
      });
      res.status(200).json(result);
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateTrackFunnel]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateRegister = onRequest(
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

      const affiliateCode = normalizeAffiliateCode(
        String(req.body?.affiliateCode ?? req.body?.code ?? "")
      );
      const displayName = String(req.body?.displayName ?? "").trim();
      if (!affiliateCode) {
        res.status(400).json({ error: "INVALID_CODE" });
        return;
      }

      const resolved = await resolveAffiliateByCode(affiliateCode);
      if (!resolved) {
        res.status(404).json({ error: "AFFILIATE_NOT_FOUND" });
        return;
      }

      await registerAffiliateAttribution({
        affiliateId: resolved.affiliateId,
        affiliateCode,
        inviteeUid: uid,
        displayName: displayName || "Member",
      });

      res.status(200).json({
        ok: true,
        affiliateCode,
        affiliateId: resolved.affiliateId,
        displayName: resolved.doc.displayName,
      });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateRegister]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateApply = onRequest(
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

      const requestedCode = normalizeAffiliateCode(
        String(req.body?.code ?? "")
      );
      const displayName = String(req.body?.displayName ?? "").trim();
      const email = String(req.body?.email ?? "").trim();
      const phone = String(req.body?.phone ?? "").trim().slice(0, 40);
      const onboarding = readAffiliateOnboarding(req.body?.onboarding);
      if (!displayName) {
        res.status(400).json({ error: "INVALID_TEXT" });
        return;
      }

      const existing = await getAffiliateForUid(uid);
      const affiliateId = existing?.affiliateId || uid;

      if (!existing && !isValidAffiliatePhone(phone)) {
        res.status(400).json({ error: "INVALID_PHONE" });
        return;
      }

      if (!existing) {
        await ensureAffiliateProfile({
          affiliateId,
          displayName,
          email: email || undefined,
          phone: phone || undefined,
          uid,
          status: "active",
        });
      }

      let attachedCode = "";
      const needsCode = !requestedCode && !existing?.primaryCode && !(existing?.codes?.length);

      if (requestedCode || needsCode) {
        let lastError: unknown;
        for (let attempt = 0; attempt < 6; attempt += 1) {
          try {
            const code =
              requestedCode || (await allocateUniqueAffiliateCode(displayName));
            const created = await createAffiliateWithCode({
              affiliateId,
              code,
              displayName: displayName || existing?.displayName || code,
              email: email || existing?.email || undefined,
              uid,
              status: existing?.status || "active",
              makePrimary: true,
            });
            attachedCode = created.code;
            lastError = null;
            break;
          } catch (error: any) {
            lastError = error;
            if (requestedCode || error?.message !== "CODE_CONFLICT") {
              throw error;
            }
          }
        }
        if (!attachedCode && lastError) throw lastError;
      }

      if (onboarding || email || phone) {
        await db()
          .collection("affiliates")
          .doc(affiliateId)
          .set(
            {
              ...(onboarding ? { onboarding } : {}),
              ...(email ? { email: email.slice(0, 120) } : {}),
              ...(phone ? { phone } : {}),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
      }

      const fresh = await getAffiliateForUid(uid);
      const codes = fresh?.codes ?? [];
      const primaryCode = pickPrimaryAffiliateCode(
        codes,
        attachedCode || fresh?.primaryCode,
        await readOwnedProcessReferralCode(uid)
      );

      res.status(200).json({
        ok: true,
        affiliateId,
        status: fresh?.status || existing?.status || "active",
        codes,
        primaryCode,
        code: primaryCode,
      });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateApply]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateSyncProfile = onRequest(
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

      const displayName = String(req.body?.displayName ?? "").trim();
      const code = String(req.body?.code ?? req.body?.affiliateCode ?? "").trim();

      const affiliate = await getAffiliateForUid(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }

      const updated = await updateAffiliateInviteProfile({
        affiliateId: affiliate.affiliateId,
        uid,
        email: affiliate.email || undefined,
        status: affiliate.status,
        displayName: displayName || affiliate.displayName,
        code,
      });

      res.status(200).json({
        ok: true,
        affiliateId: affiliate.affiliateId,
        displayName: updated.displayName,
        primaryCode: updated.primaryCode,
        codes: updated.codes.map((value) => ({
          code: value,
          displayName: updated.displayName,
          status: affiliate.status,
        })),
      });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateSyncProfile]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateDashboard = onRequest(
  {
    invoker: "public",
    cors: true,
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

      void (async () => {
        try {
          const processCode = await readOwnedProcessReferralCode(uid);
          if (!processCode) return;
          const latest = (await getAffiliateForUid(uid)) || affiliate;
          const ownsProcess = Array.isArray(latest.codes) && latest.codes.includes(processCode);
          if (latest.customPrimaryCode) {
            if (!ownsProcess) {
              await createAffiliateWithCode({
                affiliateId: latest.affiliateId,
                code: processCode,
                displayName: latest.displayName,
                email: latest.email || undefined,
                uid,
                status: latest.status,
                makePrimary: false,
              });
            }
            return;
          }
          if (latest.primaryCode !== processCode) {
            await createAffiliateWithCode({
              affiliateId: latest.affiliateId,
              code: processCode,
              displayName: latest.displayName,
              email: latest.email || undefined,
              uid,
              status: latest.status,
              makePrimary: true,
            });
          }
        } catch (syncError: any) {
          if (syncError?.message !== "CODE_CONFLICT") {
            console.warn("[affiliateDashboard] process code sync skipped", syncError);
          }
        }
      })();

      void releaseDueAffiliateCommissions().catch((releaseError) => {
        console.warn("[affiliateDashboard] releaseDue skipped", releaseError);
      });

      const data = affiliate as Record<string, any>;
      const stats = data.stats ?? {};
      const hasActivity = Boolean(
        stats.linkViews ||
          stats.storeClicks ||
          stats.referredCount ||
          stats.paywallCount ||
          stats.paidCount ||
          stats.lifetimeCents
      );

      const extrasPromise = Promise.all([
        db()
          .collection("affiliateCodes")
          .where("affiliateId", "==", affiliate.affiliateId)
          .limit(20)
          .get(),
        db()
          .collection("affiliateCommissions")
          .where("affiliateId", "==", affiliate.affiliateId)
          .limit(50)
          .get(),
        db()
          .collection("affiliatePayouts")
          .where("affiliateId", "==", affiliate.affiliateId)
          .limit(20)
          .get(),
        hasActivity
          ? readAffiliateDailySeries(affiliate.affiliateId, 30)
          : Promise.resolve(emptyDailySeries(30)),
        listPublicTikTokAccounts(affiliate.affiliateId).catch(() => []),
      ]);

      let codes: Array<{ code: string; displayName: string; status: string }> = [];
      let recentCommissions: any[] = [];
      let payouts: any[] = [];
      let series = emptyDailySeries(30);
      let tiktokAccounts: Awaited<ReturnType<typeof listPublicTikTokAccounts>> = [];

      try {
        const [codesSnap, recentSnap, payoutsSnap, dailySeries, tiktokSnap] = await extrasPromise;
        series = dailySeries;
        tiktokAccounts = tiktokSnap;
        codes = codesSnap.docs.map((doc) => ({
          code: doc.id,
          displayName: doc.data()?.displayName ?? doc.id,
          status: doc.data()?.status ?? "active",
        }));

        recentCommissions = recentSnap.docs
          .map((doc) => {
            const row = doc.data();
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

        payouts = payoutsSnap.docs
          .map((doc) => {
            const row = doc.data();
            return {
              id: doc.id,
              amountCents: row.amountCents ?? 0,
              currency: row.currency ?? "EUR",
              method: row.method ?? "stripe",
              status: row.status ?? "completed",
              createdAt: row.createdAt?.toMillis?.() ?? null,
            };
          })
          .sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0))
          .slice(0, 10);
      } catch (extraError) {
        console.warn("[affiliateDashboard] extras skipped", extraError);
      }

      if (!codes.length && Array.isArray(data.codes)) {
        codes = data.codes.map((code: string) => ({
          code,
          displayName: data.displayName ?? code,
          status: data.status ?? "active",
        }));
      }

      const primaryCode = pickPrimaryAffiliateCode(
        codes.map((row) => row.code),
        data.primaryCode || affiliate.primaryCode,
        null
      );
      if (primaryCode) {
        codes = [
          ...codes.filter((row) => row.code === primaryCode),
          ...codes.filter((row) => row.code !== primaryCode),
        ];
      }

      res.status(200).json({
        ok: true,
        affiliateId: affiliate.affiliateId,
        displayName: data.displayName ?? affiliate.displayName,
        status: data.status ?? affiliate.status,
        primaryCode,
        payoutMethod: data.payoutMethod ?? null,
        stripeConnect: {
          accountId: data.stripeAccountId ?? null,
          onboardingComplete: Boolean(data.stripeOnboardingComplete),
          payoutsEnabled: Boolean(data.stripePayoutsEnabled),
          detailsSubmitted: Boolean(data.stripeDetailsSubmitted),
          requirementsDue: Array.isArray(data.stripeRequirementsDue)
            ? data.stripeRequirementsDue
            : [],
        },
        codes,
        stats: {
          linkViews: stats.linkViews ?? 0,
          storeClicks: stats.storeClicks ?? 0,
          referredCount: stats.referredCount ?? 0,
          paywallCount: stats.paywallCount ?? 0,
          paidCount: stats.paidCount ?? 0,
          activeSubscribers: stats.activeSubscribers ?? 0,
          pendingCents: stats.pendingCents ?? 0,
          payableCents: stats.payableCents ?? 0,
          paidCents: stats.paidCents ?? 0,
          lifetimeCents: stats.lifetimeCents ?? 0,
        },
        series,
        recentCommissions,
        payouts,
        tiktok: {
          apiReady: tiktokApiReady(),
          accounts: tiktokAccounts,
          totals: tiktokTotals(tiktokAccounts),
        },
      });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateDashboard]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateAdminCreate = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
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
      verifyAffiliateAdmin(req, affiliateAdminSecret.value());

      const code = String(req.body?.code ?? "");
      const displayName = String(req.body?.displayName ?? "").trim();
      const email = String(req.body?.email ?? "").trim();
      const uid = String(req.body?.uid ?? "").trim();
      const password = String(req.body?.password ?? "").trim();
      const affiliateId =
        String(req.body?.affiliateId ?? "").trim() ||
        normalizeAffiliateCode(code) ||
        db().collection("affiliates").doc().id;

      if (!displayName) {
        res.status(400).json({ error: "INVALID_TEXT" });
        return;
      }

      let resolvedUid = uid || undefined;
      if (email && password) {
        resolvedUid = await provisionAffiliateAuthUser({
          email,
          password,
          displayName,
        });
      }

      const created = await createAffiliateWithCode({
        affiliateId,
        code,
        displayName,
        email: email || undefined,
        uid: resolvedUid,
        status: "active",
      });

      res.status(200).json({
        ok: true,
        ...created,
        ...(email && password
          ? { authEmail: email.trim().toLowerCase(), authProvisioned: true }
          : {}),
      });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateAdminCreate]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateAdminProvisionAuth = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
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
      verifyAffiliateAdmin(req, affiliateAdminSecret.value());

      const affiliateId = String(req.body?.affiliateId ?? req.body?.code ?? "").trim();
      const email = String(req.body?.email ?? "").trim();
      const password = String(req.body?.password ?? "").trim();
      const displayName = String(req.body?.displayName ?? "").trim();

      if (!affiliateId || !email || !password) {
        res.status(400).json({ error: "INVALID_TEXT" });
        return;
      }

      const normalizedId =
        normalizeAffiliateCode(affiliateId) ||
        (await resolveAffiliateByCode(affiliateId))?.affiliateId ||
        affiliateId;

      const linked = await linkAffiliateAuthUser({
        affiliateId: normalizedId,
        email,
        password,
        displayName: displayName || undefined,
      });

      res.status(200).json({ ok: true, ...linked, authProvisioned: true });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateAdminProvisionAuth]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateAdminApprove = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
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
      verifyAffiliateAdmin(req, affiliateAdminSecret.value());
      const affiliateId = String(req.body?.affiliateId ?? "").trim();
      if (!affiliateId) {
        res.status(400).json({ error: "INVALID_TEXT" });
        return;
      }

      const affiliateRef = db().collection("affiliates").doc(affiliateId);
      const snap = await affiliateRef.get();
      if (!snap.exists) {
        res.status(404).json({ error: "AFFILIATE_NOT_FOUND" });
        return;
      }

      const codes = (snap.data()?.codes as string[] | undefined) ?? [];
      const batch = db().batch();
      batch.set(
        affiliateRef,
        {
          status: "active",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      for (const code of codes) {
        batch.set(
          db().collection("affiliateCodes").doc(code),
          {
            status: "active",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
      await batch.commit();

      res.status(200).json({ ok: true, affiliateId, status: "active" });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateAdminApprove]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateAdminListPending = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
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
      verifyAffiliateAdmin(req, affiliateAdminSecret.value());

      const snap = await db()
        .collection("affiliates")
        .where("status", "==", "pending")
        .limit(100)
        .get();

      const pending = snap.docs.map((doc) => {
        const data = doc.data();
        return {
          affiliateId: doc.id,
          displayName: data.displayName ?? doc.id,
          email: data.email ?? null,
          uid: data.uid ?? null,
          codes: data.codes ?? [],
          stripeOnboardingComplete: Boolean(data.stripeOnboardingComplete),
          stripePayoutsEnabled: Boolean(data.stripePayoutsEnabled),
          createdAt: data.createdAt?.toMillis?.() ?? null,
        };
      });

      pending.sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));

      res.status(200).json({ ok: true, pending, count: pending.length });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateAdminListPending]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);

export const affiliateAdminMarkPaid = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret, stripeSecretKey],
    timeoutSeconds: 60,
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
      verifyAffiliateAdmin(req, affiliateAdminSecret.value());
      const affiliateId = String(req.body?.affiliateId ?? "").trim();
      const amountCents = Number(req.body?.amountCents ?? 0);
      const currency = String(req.body?.currency ?? "EUR").trim().toUpperCase();
      const method = String(req.body?.method ?? "stripe").trim();
      const note = String(req.body?.note ?? "").trim();

      if (!affiliateId || !Number.isFinite(amountCents) || amountCents <= 0) {
        res.status(400).json({ error: "INVALID_PAYOUT" });
        return;
      }

      await releaseDueAffiliateCommissions(affiliateId);

      const affiliateRef = db().collection("affiliates").doc(affiliateId);
      const affiliateSnap = await affiliateRef.get();
      if (!affiliateSnap.exists) {
        res.status(404).json({ error: "AFFILIATE_NOT_FOUND" });
        return;
      }

      const stats = affiliateSnap.data()?.stats ?? {};
      const affiliateData = affiliateSnap.data() ?? {};
      const payableCents = Number(stats.payableCents ?? 0);
      if (payableCents < amountCents) {
        res.status(400).json({
          error: "INVALID_PAYOUT",
          payableCents,
        });
        return;
      }

      const now = admin.firestore.Timestamp.now();
      const payoutRef = db().collection("affiliatePayouts").doc();
      let stripeTransferId: string | null = null;

      if (method === "stripe") {
        const stripeAccountId = String(affiliateData.stripeAccountId ?? "").trim();
        const payoutsEnabled = Boolean(affiliateData.stripePayoutsEnabled);
        if (!stripeAccountId || !payoutsEnabled) {
          res.status(400).json({ error: "STRIPE_NOT_READY" });
          return;
        }
        stripeTransferId = await createAffiliateStripeTransfer({
          affiliateId,
          stripeAccountId,
          amountCents,
          currency,
          payoutId: payoutRef.id,
          secret: stripeSecretKey.value(),
        });
      }

      await db().runTransaction(async (transaction) => {
        transaction.set(payoutRef, {
          affiliateId,
          amountCents,
          currency,
          method,
          note: note.slice(0, 240) || null,
          status: "completed",
          stripeTransferId,
          createdAt: now,
        });

        transaction.set(
          affiliateRef,
          {
            "stats.payableCents": admin.firestore.FieldValue.increment(-amountCents),
            "stats.paidCents": admin.firestore.FieldValue.increment(amountCents),
            updatedAt: now,
          },
          { merge: true }
        );
      });

      const payableSnap = await db()
        .collection("affiliateCommissions")
        .where("affiliateId", "==", affiliateId)
        .where("status", "==", "payable")
        .limit(500)
        .get();

      let remaining = amountCents;
      const batch = db().batch();
      for (const doc of payableSnap.docs) {
        if (remaining <= 0) break;
        const row = doc.data();
        const commissionCents = Number(row.commissionCents ?? 0);
        if (commissionCents <= 0) continue;
        if (commissionCents > remaining) continue;
        remaining -= commissionCents;
        batch.set(
          doc.ref,
          {
            status: "paid",
            paidAt: now,
            payoutId: payoutRef.id,
          },
          { merge: true }
        );
      }
      await batch.commit();

      res.status(200).json({
        ok: true,
        payoutId: payoutRef.id,
        affiliateId,
        amountCents,
        stripeTransferId,
      });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateAdminMarkPaid]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);
