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
exports.getReferralAttributionForUser = getReferralAttributionForUser;
exports.accrueReferralCommission = accrueReferralCommission;
exports.clawbackReferralCommission = clawbackReferralCommission;
exports.markReferralAttributionChurned = markReferralAttributionChurned;
exports.releaseDueReferralCommissions = releaseDueReferralCommissions;
exports.fetchReferralDashboard = fetchReferralDashboard;
const admin = __importStar(require("firebase-admin"));
const revenueCat_1 = require("./revenueCat");
const commissionShared_1 = require("./commissionShared");
const referralShared_1 = require("./referralShared");
async function getReferralAttributionForUser(inviteeUid) {
    const snap = await (0, referralShared_1.db)()
        .collection("users")
        .doc(inviteeUid)
        .collection("referralMeta")
        .doc("referredBy")
        .get();
    if (!snap.exists)
        return null;
    const data = snap.data() ?? {};
    const referrerUserId = data.referrerUserId;
    const referralCode = data.referralCode;
    const rawStatus = data.status;
    if (!referrerUserId || !referralCode)
        return null;
    if (rawStatus === "refunded")
        return null;
    let status = "pending";
    if (rawStatus === "accepted" || rawStatus === "active")
        status = "active";
    else if (rawStatus === "churned")
        status = "churned";
    return { referrerUserId, referralCode, status };
}
async function markReferralInviteAccepted(params) {
    const now = admin.firestore.Timestamp.now();
    const referredMetaRef = (0, referralShared_1.db)()
        .collection("users")
        .doc(params.inviteeUid)
        .collection("referralMeta")
        .doc("referredBy");
    const inviteRef = (0, referralShared_1.db)()
        .collection("users")
        .doc(params.referrerUserId)
        .collection("referralInvites")
        .doc(params.inviteeUid);
    const programRef = (0, referralShared_1.db)()
        .collection("users")
        .doc(params.referrerUserId)
        .collection("referralMeta")
        .doc("program");
    await (0, referralShared_1.db)().runTransaction(async (transaction) => {
        const referredMeta = await transaction.get(referredMetaRef);
        const wasPending = !referredMeta.exists ||
            referredMeta.data()?.status === "pending" ||
            referredMeta.data()?.status === "processing";
        const acceptedPayload = {
            status: "accepted",
            acceptedAt: now,
        };
        transaction.set(referredMetaRef, acceptedPayload, { merge: true });
        transaction.set(inviteRef, acceptedPayload, { merge: true });
        if (wasPending) {
            transaction.set(programRef, {
                acceptedCount: admin.firestore.FieldValue.increment(1),
                pendingCount: admin.firestore.FieldValue.increment(-1),
                "stats.activeSubscribers": admin.firestore.FieldValue.increment(1),
                lastCommissionAt: now,
            }, { merge: true });
        }
        else {
            transaction.set(programRef, { lastCommissionAt: now }, { merge: true });
        }
    });
}
async function accrueReferralCommission(params) {
    const eventType = String(params.event?.type ?? "");
    const rcEventId = String(params.event?.id ?? params.event?.event_timestamp_ms ?? "");
    if (!rcEventId)
        return { created: false, skipped: "NO_EVENT_ID" };
    const isRenewal = eventType === "RENEWAL" && (0, revenueCat_1.isPaidPurchaseEvent)(params.event);
    const isInitial = eventType === "INITIAL_PURCHASE" && (0, revenueCat_1.isPaidPurchaseEvent)(params.event);
    if (!isRenewal && !isInitial) {
        return { created: false, skipped: eventType || "UNSUPPORTED_EVENT" };
    }
    const attribution = await getReferralAttributionForUser(params.inviteeUid);
    if (!attribution || attribution.status === "churned" || attribution.status === "refunded") {
        return { created: false, skipped: "NOT_REFERRED" };
    }
    const amounts = (0, commissionShared_1.commissionFromRevenueCatEvent)(params.event);
    if (!amounts)
        return { created: false, skipped: "NO_COMMISSION" };
    const commissionId = (0, commissionShared_1.commissionDocId)(attribution.referrerUserId, rcEventId);
    const commissionRef = (0, referralShared_1.db)().collection("referralCommissions").doc(commissionId);
    const programRef = (0, referralShared_1.db)()
        .collection("users")
        .doc(attribution.referrerUserId)
        .collection("referralMeta")
        .doc("program");
    const existing = await commissionRef.get();
    if (existing.exists)
        return { created: false, skipped: "DUPLICATE" };
    const now = admin.firestore.Timestamp.now();
    const holdUntil = admin.firestore.Timestamp.fromMillis(now.toMillis() + commissionShared_1.COMMISSION_HOLD_DAYS * 86_400_000);
    const commission = {
        referrerUserId: attribution.referrerUserId,
        inviteeUid: params.inviteeUid,
        referralCode: attribution.referralCode,
        rcEventId,
        rcEventType: eventType,
        productId: amounts.productId,
        grossCents: amounts.grossCents,
        netCents: amounts.netCents,
        commissionCents: amounts.commissionCents,
        commissionRate: amounts.commissionRate,
        currency: amounts.currency,
        status: "pending_hold",
        holdUntil,
        createdAt: now,
    };
    await (0, referralShared_1.db)().runTransaction(async (transaction) => {
        transaction.set(commissionRef, commission);
        transaction.set(programRef, {
            "stats.pendingCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
            "stats.lifetimeCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
            updatedAt: now,
        }, { merge: true });
    });
    await markReferralInviteAccepted({
        referrerUserId: attribution.referrerUserId,
        inviteeUid: params.inviteeUid,
    });
    return { created: true, commissionId };
}
async function clawbackReferralCommission(params) {
    const attribution = await getReferralAttributionForUser(params.inviteeUid);
    if (!attribution)
        return { clawed: 0 };
    const originalTransactionId = String(params.event?.original_transaction_id ??
        params.event?.transaction_id ??
        params.event?.id ??
        "");
    if (!originalTransactionId)
        return { clawed: 0 };
    const commissions = await (0, referralShared_1.db)()
        .collection("referralCommissions")
        .where("referrerUserId", "==", attribution.referrerUserId)
        .where("inviteeUid", "==", params.inviteeUid)
        .limit(50)
        .get();
    let clawed = 0;
    const batch = (0, referralShared_1.db)().batch();
    const now = admin.firestore.Timestamp.now();
    const programRef = (0, referralShared_1.db)()
        .collection("users")
        .doc(attribution.referrerUserId)
        .collection("referralMeta")
        .doc("program");
    for (const doc of commissions.docs) {
        const data = doc.data();
        if (data.status === "clawed_back" || data.status === "paid")
            continue;
        if (data.rcEventId !== originalTransactionId &&
            !String(data.rcEventId).includes(originalTransactionId)) {
            continue;
        }
        clawed += data.commissionCents;
        batch.set(doc.ref, { status: "clawed_back", clawedBackAt: now }, { merge: true });
        const statField = data.status === "payable" ? "payableCents" : "pendingCents";
        batch.set(programRef, {
            [`stats.${statField}`]: admin.firestore.FieldValue.increment(-data.commissionCents),
            "stats.lifetimeCents": admin.firestore.FieldValue.increment(-data.commissionCents),
            updatedAt: now,
        }, { merge: true });
    }
    batch.set((0, referralShared_1.db)().collection("users").doc(params.inviteeUid).collection("referralMeta").doc("referredBy"), { status: "refunded" }, { merge: true });
    if (clawed > 0)
        await batch.commit();
    return { clawed };
}
async function markReferralAttributionChurned(inviteeUid) {
    const attribution = await getReferralAttributionForUser(inviteeUid);
    if (!attribution)
        return;
    const now = admin.firestore.Timestamp.now();
    await (0, referralShared_1.db)()
        .collection("users")
        .doc(inviteeUid)
        .collection("referralMeta")
        .doc("referredBy")
        .set({ status: "churned" }, { merge: true });
    await (0, referralShared_1.db)()
        .collection("users")
        .doc(attribution.referrerUserId)
        .collection("referralMeta")
        .doc("program")
        .set({
        "stats.activeSubscribers": admin.firestore.FieldValue.increment(-1),
        updatedAt: now,
    }, { merge: true });
}
async function releaseDueReferralCommissions(referrerUserId) {
    const now = admin.firestore.Timestamp.now();
    let query = (0, referralShared_1.db)()
        .collection("referralCommissions")
        .where("status", "==", "pending_hold")
        .where("holdUntil", "<=", now)
        .limit(200);
    if (referrerUserId) {
        query = query.where("referrerUserId", "==", referrerUserId);
    }
    const snapshot = await query.get();
    if (snapshot.empty)
        return 0;
    let released = 0;
    for (const doc of snapshot.docs) {
        const data = doc.data();
        await (0, referralShared_1.db)().runTransaction(async (transaction) => {
            const fresh = await transaction.get(doc.ref);
            if (!fresh.exists)
                return;
            const current = fresh.data();
            if (current.status !== "pending_hold")
                return;
            if (current.holdUntil.toMillis() > now.toMillis())
                return;
            transaction.set(doc.ref, { status: "payable", payableAt: now }, { merge: true });
            const programRef = (0, referralShared_1.db)()
                .collection("users")
                .doc(current.referrerUserId)
                .collection("referralMeta")
                .doc("program");
            transaction.set(programRef, {
                "stats.pendingCents": admin.firestore.FieldValue.increment(-current.commissionCents),
                "stats.payableCents": admin.firestore.FieldValue.increment(current.commissionCents),
                updatedAt: now,
            }, { merge: true });
        });
        released += 1;
    }
    return released;
}
async function fetchReferralDashboard(uid) {
    await releaseDueReferralCommissions(uid);
    const programSnap = await (0, referralShared_1.db)()
        .collection("users")
        .doc(uid)
        .collection("referralMeta")
        .doc("program")
        .get();
    const program = programSnap.data() ?? {};
    const stats = program.stats ?? {};
    const commissionsSnap = await (0, referralShared_1.db)()
        .collection("referralCommissions")
        .where("referrerUserId", "==", uid)
        .limit(50)
        .get();
    const recentCommissions = commissionsSnap.docs
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
    return {
        ok: true,
        referralCode: program.referralCode ?? null,
        displayName: program.displayName ?? null,
        pendingCount: program.pendingCount ?? 0,
        acceptedCount: program.acceptedCount ?? 0,
        stats: {
            activeSubscribers: stats.activeSubscribers ?? 0,
            pendingCents: stats.pendingCents ?? 0,
            payableCents: stats.payableCents ?? 0,
            paidCents: stats.paidCents ?? 0,
            lifetimeCents: stats.lifetimeCents ?? 0,
        },
        commissionRate: commissionShared_1.COMMISSION_RATE,
        holdDays: commissionShared_1.COMMISSION_HOLD_DAYS,
        recentCommissions,
    };
}
//# sourceMappingURL=referralCommissions.js.map