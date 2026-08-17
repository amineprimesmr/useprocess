"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.affiliateAdminMarkPaid = exports.affiliateAdminApprove = exports.affiliateAdminProvisionAuth = exports.affiliateAdminCreate = exports.affiliateDashboard = exports.affiliateSyncProfile = exports.affiliateApply = exports.affiliateRegister = exports.affiliateResolveCode = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const affiliateShared_1 = require("./affiliateShared");
const referralShared_1 = require("./referralShared");
const affiliateAdminSecret = (0, params_1.defineSecret)("AFFILIATE_ADMIN_SECRET");
exports.affiliateResolveCode = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 20,
    memory: "256MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
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
        const resolved = await (0, affiliateShared_1.resolveCodeKind)(code);
        if (!resolved) {
            res.status(404).json({ error: "CODE_NOT_FOUND" });
            return;
        }
        res.status(200).json({ ok: true, ...resolved });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateResolveCode]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateRegister = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const uid = await (0, referralShared_1.verifyFirebaseUser)(req);
        await (0, referralShared_1.verifyAppAttestation)(req);
        const affiliateCode = (0, affiliateShared_1.normalizeAffiliateCode)(String(req.body?.affiliateCode ?? req.body?.code ?? ""));
        const displayName = String(req.body?.displayName ?? "").trim();
        if (!affiliateCode) {
            res.status(400).json({ error: "INVALID_CODE" });
            return;
        }
        const resolved = await (0, affiliateShared_1.resolveAffiliateByCode)(affiliateCode);
        if (!resolved) {
            res.status(404).json({ error: "AFFILIATE_NOT_FOUND" });
            return;
        }
        await (0, affiliateShared_1.registerAffiliateAttribution)({
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
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateRegister]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateApply = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const uid = await (0, referralShared_1.verifyFirebaseUser)(req);
        await (0, referralShared_1.verifyAppAttestation)(req);
        const requestedCode = (0, affiliateShared_1.normalizeAffiliateCode)(String(req.body?.code ?? ""));
        const displayName = String(req.body?.displayName ?? "").trim();
        const email = String(req.body?.email ?? "").trim();
        const paypalEmail = String(req.body?.paypalEmail ?? "").trim();
        if (!displayName) {
            res.status(400).json({ error: "INVALID_TEXT" });
            return;
        }
        const affiliateId = uid;
        const code = requestedCode ||
            (0, affiliateShared_1.normalizeAffiliateCode)(displayName.replace(/[^A-Za-z0-9]/g, "")).slice(0, 12);
        const existing = await (0, affiliateShared_1.getAffiliateForUid)(uid);
        if (existing) {
            res.status(200).json({
                ok: true,
                affiliateId: existing.affiliateId,
                status: existing.status,
                codes: existing.codes ?? [],
            });
            return;
        }
        await (0, affiliateShared_1.createAffiliateWithCode)({
            affiliateId,
            code,
            displayName,
            email: email || undefined,
            uid,
            status: "pending",
        });
        if (paypalEmail) {
            await (0, affiliateShared_1.db)().collection("affiliates").doc(affiliateId).set({
                paypalEmail: paypalEmail.slice(0, 120),
                payoutMethod: "paypal",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        res.status(200).json({
            ok: true,
            affiliateId,
            code,
            status: "pending",
        });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateApply]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateSyncProfile = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const uid = await (0, referralShared_1.verifyFirebaseUser)(req);
        await (0, referralShared_1.verifyAppAttestation)(req);
        const paypalEmail = String(req.body?.paypalEmail ?? "").trim();
        const payoutMethod = String(req.body?.payoutMethod ?? "paypal").trim();
        const affiliate = await (0, affiliateShared_1.getAffiliateForUid)(uid);
        if (!affiliate) {
            res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
            return;
        }
        await (0, affiliateShared_1.db)()
            .collection("affiliates")
            .doc(affiliate.affiliateId)
            .set({
            uid,
            paypalEmail: paypalEmail.slice(0, 120) || null,
            payoutMethod: payoutMethod === "bank" ? "bank" : "paypal",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        res.status(200).json({ ok: true, affiliateId: affiliate.affiliateId });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateSyncProfile]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateDashboard = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 45,
    memory: "512MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const uid = await (0, referralShared_1.verifyFirebaseUser)(req);
        await (0, referralShared_1.verifyAppAttestation)(req);
        const affiliate = await (0, affiliateShared_1.getAffiliateForUid)(uid);
        if (!affiliate) {
            res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
            return;
        }
        try {
            await (0, affiliateShared_1.releaseDueAffiliateCommissions)();
        }
        catch (releaseError) {
            console.warn("[affiliateDashboard] releaseDue skipped", releaseError);
        }
        const refreshed = await (0, affiliateShared_1.db)()
            .collection("affiliates")
            .doc(affiliate.affiliateId)
            .get();
        const data = refreshed.data() ?? {};
        const stats = data.stats ?? {};
        const codesSnap = await (0, affiliateShared_1.db)()
            .collection("affiliateCodes")
            .where("affiliateId", "==", affiliate.affiliateId)
            .limit(20)
            .get();
        const codes = codesSnap.docs.map((doc) => ({
            code: doc.id,
            displayName: doc.data()?.displayName ?? doc.id,
            status: doc.data()?.status ?? "active",
        }));
        const recentSnap = await (0, affiliateShared_1.db)()
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
        const payoutsSnap = await (0, affiliateShared_1.db)()
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
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateDashboard]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateAdminCreate = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        (0, affiliateShared_1.verifyAffiliateAdmin)(req, affiliateAdminSecret.value());
        const code = String(req.body?.code ?? "");
        const displayName = String(req.body?.displayName ?? "").trim();
        const email = String(req.body?.email ?? "").trim();
        const uid = String(req.body?.uid ?? "").trim();
        const password = String(req.body?.password ?? "").trim();
        const affiliateId = String(req.body?.affiliateId ?? "").trim() ||
            (0, affiliateShared_1.normalizeAffiliateCode)(code) ||
            (0, affiliateShared_1.db)().collection("affiliates").doc().id;
        if (!displayName) {
            res.status(400).json({ error: "INVALID_TEXT" });
            return;
        }
        let resolvedUid = uid || undefined;
        if (email && password) {
            resolvedUid = await (0, affiliateShared_1.provisionAffiliateAuthUser)({
                email,
                password,
                displayName,
            });
        }
        const created = await (0, affiliateShared_1.createAffiliateWithCode)({
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
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateAdminCreate]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateAdminProvisionAuth = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        (0, affiliateShared_1.verifyAffiliateAdmin)(req, affiliateAdminSecret.value());
        const affiliateId = String(req.body?.affiliateId ?? req.body?.code ?? "").trim();
        const email = String(req.body?.email ?? "").trim();
        const password = String(req.body?.password ?? "").trim();
        const displayName = String(req.body?.displayName ?? "").trim();
        if (!affiliateId || !email || !password) {
            res.status(400).json({ error: "INVALID_TEXT" });
            return;
        }
        const normalizedId = (0, affiliateShared_1.normalizeAffiliateCode)(affiliateId) ||
            (await (0, affiliateShared_1.resolveAffiliateByCode)(affiliateId))?.affiliateId ||
            affiliateId;
        const linked = await (0, affiliateShared_1.linkAffiliateAuthUser)({
            affiliateId: normalizedId,
            email,
            password,
            displayName: displayName || undefined,
        });
        res.status(200).json({ ok: true, ...linked, authProvisioned: true });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateAdminProvisionAuth]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateAdminApprove = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        (0, affiliateShared_1.verifyAffiliateAdmin)(req, affiliateAdminSecret.value());
        const affiliateId = String(req.body?.affiliateId ?? "").trim();
        if (!affiliateId) {
            res.status(400).json({ error: "INVALID_TEXT" });
            return;
        }
        const affiliateRef = (0, affiliateShared_1.db)().collection("affiliates").doc(affiliateId);
        const snap = await affiliateRef.get();
        if (!snap.exists) {
            res.status(404).json({ error: "AFFILIATE_NOT_FOUND" });
            return;
        }
        const codes = snap.data()?.codes ?? [];
        const batch = (0, affiliateShared_1.db)().batch();
        batch.set(affiliateRef, {
            status: "active",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        for (const code of codes) {
            batch.set((0, affiliateShared_1.db)().collection("affiliateCodes").doc(code), {
                status: "active",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        await batch.commit();
        res.status(200).json({ ok: true, affiliateId, status: "active" });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateAdminApprove]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateAdminMarkPaid = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret],
    timeoutSeconds: 60,
    memory: "512MiB",
}, async (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        (0, affiliateShared_1.verifyAffiliateAdmin)(req, affiliateAdminSecret.value());
        const affiliateId = String(req.body?.affiliateId ?? "").trim();
        const amountCents = Number(req.body?.amountCents ?? 0);
        const currency = String(req.body?.currency ?? "EUR").trim().toUpperCase();
        const method = String(req.body?.method ?? "paypal").trim();
        const note = String(req.body?.note ?? "").trim();
        if (!affiliateId || !Number.isFinite(amountCents) || amountCents <= 0) {
            res.status(400).json({ error: "INVALID_PAYOUT" });
            return;
        }
        await (0, affiliateShared_1.releaseDueAffiliateCommissions)(affiliateId);
        const affiliateRef = (0, affiliateShared_1.db)().collection("affiliates").doc(affiliateId);
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
        const payoutRef = (0, affiliateShared_1.db)().collection("affiliatePayouts").doc();
        await (0, affiliateShared_1.db)().runTransaction(async (transaction) => {
            transaction.set(payoutRef, {
                affiliateId,
                amountCents,
                currency,
                method,
                note: note.slice(0, 240) || null,
                status: "completed",
                createdAt: now,
            });
            transaction.set(affiliateRef, {
                "stats.payableCents": admin.firestore.FieldValue.increment(-amountCents),
                "stats.paidCents": admin.firestore.FieldValue.increment(amountCents),
                updatedAt: now,
            }, { merge: true });
        });
        const payableSnap = await (0, affiliateShared_1.db)()
            .collection("affiliateCommissions")
            .where("affiliateId", "==", affiliateId)
            .where("status", "==", "payable")
            .limit(500)
            .get();
        let remaining = amountCents;
        const batch = (0, affiliateShared_1.db)().batch();
        for (const doc of payableSnap.docs) {
            if (remaining <= 0)
                break;
            const row = doc.data();
            const commissionCents = Number(row.commissionCents ?? 0);
            if (commissionCents <= 0)
                continue;
            if (commissionCents > remaining)
                continue;
            remaining -= commissionCents;
            batch.set(doc.ref, {
                status: "paid",
                paidAt: now,
                payoutId: payoutRef.id,
            }, { merge: true });
        }
        await batch.commit();
        res.status(200).json({
            ok: true,
            payoutId: payoutRef.id,
            affiliateId,
            amountCents,
        });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateAdminMarkPaid]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
//# sourceMappingURL=affiliate.js.map