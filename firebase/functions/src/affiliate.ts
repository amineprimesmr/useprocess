import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import {
  affiliateHttpStatus,
  createAffiliateWithCode,
  db,
  getAffiliateForUid,
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
  setCors,
  verifyAppAttestation,
  verifyFirebaseUser,
} from "./referralShared";

const affiliateAdminSecret = defineSecret("AFFILIATE_ADMIN_SECRET");

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
      const paypalEmail = String(req.body?.paypalEmail ?? "").trim();
      if (!displayName) {
        res.status(400).json({ error: "INVALID_TEXT" });
        return;
      }

      const affiliateId = uid;
      const code =
        requestedCode ||
        normalizeAffiliateCode(displayName.replace(/[^A-Za-z0-9]/g, "")).slice(
          0,
          12
        );

      const existing = await getAffiliateForUid(uid);
      if (existing) {
        res.status(200).json({
          ok: true,
          affiliateId: existing.affiliateId,
          status: existing.status,
          codes: existing.codes ?? [],
        });
        return;
      }

      await createAffiliateWithCode({
        affiliateId,
        code,
        displayName,
        email: email || undefined,
        uid,
        status: "pending",
      });

      if (paypalEmail) {
        await db().collection("affiliates").doc(affiliateId).set(
          {
            paypalEmail: paypalEmail.slice(0, 120),
            payoutMethod: "paypal",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      res.status(200).json({
        ok: true,
        affiliateId,
        code,
        status: "pending",
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

      const paypalEmail = String(req.body?.paypalEmail ?? "").trim();
      const payoutMethod = String(req.body?.payoutMethod ?? "paypal").trim();

      const affiliate = await getAffiliateForUid(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }

      await db()
        .collection("affiliates")
        .doc(affiliate.affiliateId)
        .set(
          {
            uid,
            paypalEmail: paypalEmail.slice(0, 120) || null,
            payoutMethod: payoutMethod === "bank" ? "bank" : "paypal",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      res.status(200).json({ ok: true, affiliateId: affiliate.affiliateId });
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

      const affiliate = await getAffiliateForUid(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }

      try {
        await releaseDueAffiliateCommissions();
      } catch (releaseError) {
        console.warn("[affiliateDashboard] releaseDue skipped", releaseError);
      }

      const refreshed = await db()
        .collection("affiliates")
        .doc(affiliate.affiliateId)
        .get();
      const data = refreshed.data() ?? {};
      const stats = data.stats ?? {};

      const codesSnap = await db()
        .collection("affiliateCodes")
        .where("affiliateId", "==", affiliate.affiliateId)
        .limit(20)
        .get();
      const codes = codesSnap.docs.map((doc) => ({
        code: doc.id,
        displayName: doc.data()?.displayName ?? doc.id,
        status: doc.data()?.status ?? "active",
      }));

      const recentSnap = await db()
        .collection("affiliateCommissions")
        .where("affiliateId", "==", affiliate.affiliateId)
        .limit(50)
        .get();

      const recentCommissions = recentSnap.docs
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

      const payoutsSnap = await db()
        .collection("affiliatePayouts")
        .where("affiliateId", "==", affiliate.affiliateId)
        .limit(20)
        .get();

      const payouts = payoutsSnap.docs
        .map((doc) => {
        const row = doc.data();
        return {
          id: doc.id,
          amountCents: row.amountCents ?? 0,
          currency: row.currency ?? "EUR",
          method: row.method ?? "paypal",
          status: row.status ?? "completed",
          createdAt: row.createdAt?.toMillis?.() ?? null,
        };
      })
        .sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0))
        .slice(0, 10);

      res.status(200).json({
        ok: true,
        affiliateId: affiliate.affiliateId,
        displayName: data.displayName ?? affiliate.displayName,
        status: data.status ?? affiliate.status,
        paypalEmail: data.paypalEmail ?? null,
        payoutMethod: data.payoutMethod ?? "paypal",
        codes,
        stats: {
          referredCount: stats.referredCount ?? 0,
          activeSubscribers: stats.activeSubscribers ?? 0,
          pendingCents: stats.pendingCents ?? 0,
          payableCents: stats.payableCents ?? 0,
          paidCents: stats.paidCents ?? 0,
          lifetimeCents: stats.lifetimeCents ?? 0,
        },
        recentCommissions,
        payouts,
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
          paypalEmail: data.paypalEmail ?? null,
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
    secrets: [affiliateAdminSecret],
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
      const method = String(req.body?.method ?? "paypal").trim();
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

      await db().runTransaction(async (transaction) => {
        transaction.set(payoutRef, {
          affiliateId,
          amountCents,
          currency,
          method,
          note: note.slice(0, 240) || null,
          status: "completed",
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
      });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateAdminMarkPaid]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);
