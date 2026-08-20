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
exports.commissionFromRevenueCatEvent = exports.LIFETIME_PRODUCT_ID = exports.AFFILIATE_NET_FACTOR = exports.AFFILIATE_HOLD_DAYS = exports.AFFILIATE_COMMISSION_RATE = void 0;
exports.db = db;
exports.normalizeAffiliateCode = normalizeAffiliateCode;
exports.affiliateHttpStatus = affiliateHttpStatus;
exports.resolveAffiliateByCode = resolveAffiliateByCode;
exports.resolveCodeKind = resolveCodeKind;
exports.commissionDocId = commissionDocId;
exports.registerAffiliateAttribution = registerAffiliateAttribution;
exports.getAffiliateAttributionForUser = getAffiliateAttributionForUser;
exports.accrueAffiliateCommission = accrueAffiliateCommission;
exports.clawbackAffiliateCommission = clawbackAffiliateCommission;
exports.markAffiliateAttributionChurned = markAffiliateAttributionChurned;
exports.releaseDueAffiliateCommissions = releaseDueAffiliateCommissions;
exports.createAffiliateWithCode = createAffiliateWithCode;
exports.ensureEmailPasswordSignInEnabled = ensureEmailPasswordSignInEnabled;
exports.provisionAffiliateAuthUser = provisionAffiliateAuthUser;
exports.linkAffiliateAuthUser = linkAffiliateAuthUser;
exports.verifyAffiliateAdmin = verifyAffiliateAdmin;
exports.getAffiliateForUid = getAffiliateForUid;
exports.formatMoney = formatMoney;
const admin = __importStar(require("firebase-admin"));
const revenueCat_1 = require("./revenueCat");
const commissionShared_1 = require("./commissionShared");
Object.defineProperty(exports, "LIFETIME_PRODUCT_ID", { enumerable: true, get: function () { return commissionShared_1.LIFETIME_PRODUCT_ID; } });
Object.defineProperty(exports, "commissionFromRevenueCatEvent", { enumerable: true, get: function () { return commissionShared_1.commissionFromRevenueCatEvent; } });
const referralShared_1 = require("./referralShared");
exports.AFFILIATE_COMMISSION_RATE = commissionShared_1.COMMISSION_RATE;
exports.AFFILIATE_HOLD_DAYS = commissionShared_1.COMMISSION_HOLD_DAYS;
exports.AFFILIATE_NET_FACTOR = commissionShared_1.COMMISSION_NET_FACTOR;
function db() {
    return admin.firestore();
}
function normalizeAffiliateCode(raw) {
    return String(raw || "")
        .trim()
        .toUpperCase()
        .replace(/\s+/g, "")
        .replace(/[^A-Z0-9-]/g, "")
        .slice(0, 24);
}
function affiliateHttpStatus(message) {
    if (message === "UNAUTHORIZED")
        return 401;
    if (message === "FORBIDDEN")
        return 403;
    if (message === "INVALID_CODE")
        return 400;
    if (message === "INVALID_APP_CHECK")
        return 401;
    if (message === "SELF_ATTRIBUTION")
        return 400;
    if (message === "ALREADY_ATTRIBUTED")
        return 409;
    if (message === "AFFILIATE_NOT_FOUND")
        return 404;
    if (message === "AFFILIATE_INACTIVE")
        return 403;
    if (message === "AFFILIATE_NOT_LINKED")
        return 403;
    if (message === "CODE_CONFLICT")
        return 409;
    if (message === "INVALID_ADMIN")
        return 401;
    if (message === "INVALID_TEXT")
        return 400;
    if (message === "INVALID_PAYOUT")
        return 400;
    return 500;
}
async function resolveAffiliateByCode(code) {
    const normalized = normalizeAffiliateCode(code);
    if (!normalized)
        return null;
    const snapshot = await db().collection("affiliateCodes").doc(normalized).get();
    if (!snapshot.exists)
        return null;
    const data = snapshot.data();
    if (!data?.affiliateId || data.status !== "active")
        return null;
    return { affiliateId: data.affiliateId, doc: data };
}
async function resolveCodeKind(code) {
    const normalizedAffiliate = normalizeAffiliateCode(code);
    if (normalizedAffiliate) {
        const affiliateSnap = await db()
            .collection("affiliateCodes")
            .doc(normalizedAffiliate)
            .get();
        if (affiliateSnap.exists) {
            const data = affiliateSnap.data();
            if (data?.affiliateId && data.status === "active") {
                return {
                    type: "affiliate",
                    code: normalizedAffiliate,
                    displayName: data.displayName ?? normalizedAffiliate,
                    affiliateId: data.affiliateId,
                };
            }
        }
    }
    const normalizedReferral = (0, referralShared_1.normalizeReferralCode)(code);
    if (!(0, referralShared_1.isValidReferralCode)(normalizedReferral))
        return null;
    const referrerUserId = await (0, referralShared_1.resolveReferrerUserId)(normalizedReferral);
    if (!referrerUserId)
        return null;
    return {
        type: "referral",
        code: normalizedReferral,
        referrerUserId,
    };
}
function commissionDocId(affiliateId, rcEventId) {
    return (0, commissionShared_1.commissionDocId)(affiliateId, rcEventId);
}
async function registerAffiliateAttribution(params) {
    const affiliateRef = db().collection("affiliates").doc(params.affiliateId);
    const affiliateSnap = await affiliateRef.get();
    if (!affiliateSnap.exists)
        throw new Error("AFFILIATE_NOT_FOUND");
    const affiliate = affiliateSnap.data();
    if (!affiliate || affiliate.status !== "active") {
        throw new Error("AFFILIATE_INACTIVE");
    }
    if (affiliate.uid && affiliate.uid === params.inviteeUid) {
        throw new Error("SELF_ATTRIBUTION");
    }
    const referredMetaRef = db()
        .collection("users")
        .doc(params.inviteeUid)
        .collection("affiliateMeta")
        .doc("referredBy");
    const attributionRef = affiliateRef
        .collection("attributions")
        .doc(params.inviteeUid);
    await db().runTransaction(async (transaction) => {
        const existing = await transaction.get(referredMetaRef);
        if (existing.exists)
            throw new Error("ALREADY_ATTRIBUTED");
        const now = admin.firestore.Timestamp.now();
        transaction.set(referredMetaRef, {
            affiliateId: params.affiliateId,
            affiliateCode: params.affiliateCode,
            registeredAt: now,
            status: "active",
        });
        transaction.set(attributionRef, {
            inviteeUid: params.inviteeUid,
            affiliateCode: params.affiliateCode,
            displayName: params.displayName.slice(0, 80),
            registeredAt: now,
            status: "active",
        });
        transaction.set(affiliateRef, {
            "stats.referredCount": admin.firestore.FieldValue.increment(1),
            updatedAt: now,
        }, { merge: true });
    });
}
async function getAffiliateAttributionForUser(inviteeUid) {
    const snap = await db()
        .collection("users")
        .doc(inviteeUid)
        .collection("affiliateMeta")
        .doc("referredBy")
        .get();
    if (!snap.exists)
        return null;
    const data = snap.data() ?? {};
    const affiliateId = data.affiliateId;
    const affiliateCode = data.affiliateCode;
    const status = data.status ?? "active";
    if (!affiliateId || !affiliateCode)
        return null;
    if (status === "refunded")
        return null;
    return { affiliateId, affiliateCode, status };
}
async function accrueAffiliateCommission(params) {
    const eventType = String(params.event?.type ?? "");
    const rcEventId = String(params.event?.id ?? params.event?.event_timestamp_ms ?? "");
    if (!rcEventId)
        return { created: false, skipped: "NO_EVENT_ID" };
    const isRenewal = eventType === "RENEWAL" && (0, revenueCat_1.isPaidPurchaseEvent)(params.event);
    const isInitial = eventType === "INITIAL_PURCHASE" && (0, revenueCat_1.isPaidPurchaseEvent)(params.event);
    if (!isRenewal && !isInitial) {
        return { created: false, skipped: eventType || "UNSUPPORTED_EVENT" };
    }
    const attribution = await getAffiliateAttributionForUser(params.inviteeUid);
    if (!attribution || attribution.status !== "active") {
        return { created: false, skipped: "NOT_ATTRIBUTED" };
    }
    const amounts = (0, commissionShared_1.commissionFromRevenueCatEvent)(params.event);
    if (!amounts)
        return { created: false, skipped: "NO_COMMISSION" };
    const commissionId = commissionDocId(attribution.affiliateId, rcEventId);
    const commissionRef = db().collection("affiliateCommissions").doc(commissionId);
    const affiliateRef = db().collection("affiliates").doc(attribution.affiliateId);
    const existing = await commissionRef.get();
    if (existing.exists)
        return { created: false, skipped: "DUPLICATE" };
    const now = admin.firestore.Timestamp.now();
    const holdUntil = admin.firestore.Timestamp.fromMillis(now.toMillis() + exports.AFFILIATE_HOLD_DAYS * 86_400_000);
    const commission = {
        affiliateId: attribution.affiliateId,
        inviteeUid: params.inviteeUid,
        affiliateCode: attribution.affiliateCode,
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
    await db().runTransaction(async (transaction) => {
        transaction.set(commissionRef, commission);
        transaction.set(affiliateRef, {
            "stats.pendingCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
            "stats.lifetimeCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
            updatedAt: now,
        }, { merge: true });
        transaction.set(affiliateRef.collection("attributions").doc(params.inviteeUid), {
            lastCommissionAt: now,
            lastProductId: amounts.productId ?? null,
        }, { merge: true });
    });
    return { created: true, commissionId };
}
async function clawbackAffiliateCommission(params) {
    const attribution = await getAffiliateAttributionForUser(params.inviteeUid);
    if (!attribution)
        return { clawed: 0 };
    const originalTransactionId = String(params.event?.original_transaction_id ??
        params.event?.transaction_id ??
        params.event?.id ??
        "");
    if (!originalTransactionId)
        return { clawed: 0 };
    const commissions = await db()
        .collection("affiliateCommissions")
        .where("affiliateId", "==", attribution.affiliateId)
        .where("inviteeUid", "==", params.inviteeUid)
        .limit(50)
        .get();
    let clawed = 0;
    const batch = db().batch();
    const now = admin.firestore.Timestamp.now();
    const affiliateRef = db().collection("affiliates").doc(attribution.affiliateId);
    for (const doc of commissions.docs) {
        const data = doc.data();
        if (data.status === "clawed_back" || data.status === "paid")
            continue;
        if (data.rcEventId !== originalTransactionId &&
            !String(data.rcEventId).includes(originalTransactionId)) {
            continue;
        }
        clawed += data.commissionCents;
        batch.set(doc.ref, {
            status: "clawed_back",
            clawedBackAt: now,
        }, { merge: true });
        const statField = data.status === "payable" ? "payableCents" : "pendingCents";
        batch.set(affiliateRef, {
            [`stats.${statField}`]: admin.firestore.FieldValue.increment(-data.commissionCents),
            "stats.lifetimeCents": admin.firestore.FieldValue.increment(-data.commissionCents),
            updatedAt: now,
        }, { merge: true });
    }
    batch.set(db()
        .collection("users")
        .doc(params.inviteeUid)
        .collection("affiliateMeta")
        .doc("referredBy"), { status: "refunded" }, { merge: true });
    batch.set(affiliateRef.collection("attributions").doc(params.inviteeUid), { status: "refunded" }, { merge: true });
    if (clawed > 0)
        await batch.commit();
    return { clawed };
}
async function markAffiliateAttributionChurned(inviteeUid) {
    const attribution = await getAffiliateAttributionForUser(inviteeUid);
    if (!attribution)
        return;
    const now = admin.firestore.Timestamp.now();
    await db()
        .collection("users")
        .doc(inviteeUid)
        .collection("affiliateMeta")
        .doc("referredBy")
        .set({ status: "churned" }, { merge: true });
    await db()
        .collection("affiliates")
        .doc(attribution.affiliateId)
        .collection("attributions")
        .doc(inviteeUid)
        .set({ status: "churned" }, { merge: true });
    await db()
        .collection("affiliates")
        .doc(attribution.affiliateId)
        .set({
        "stats.activeSubscribers": admin.firestore.FieldValue.increment(-1),
        updatedAt: now,
    }, { merge: true });
}
async function releaseDueAffiliateCommissions(affiliateId) {
    const now = admin.firestore.Timestamp.now();
    let query = db()
        .collection("affiliateCommissions")
        .where("status", "==", "pending_hold")
        .where("holdUntil", "<=", now)
        .limit(200);
    if (affiliateId) {
        query = query.where("affiliateId", "==", affiliateId);
    }
    const snapshot = await query.get();
    if (snapshot.empty)
        return 0;
    let released = 0;
    for (const doc of snapshot.docs) {
        const data = doc.data();
        await db().runTransaction(async (transaction) => {
            const fresh = await transaction.get(doc.ref);
            if (!fresh.exists)
                return;
            const current = fresh.data();
            if (current.status !== "pending_hold")
                return;
            if (current.holdUntil.toMillis() > now.toMillis())
                return;
            transaction.set(doc.ref, {
                status: "payable",
                payableAt: now,
            }, { merge: true });
            transaction.set(db().collection("affiliates").doc(current.affiliateId), {
                "stats.pendingCents": admin.firestore.FieldValue.increment(-current.commissionCents),
                "stats.payableCents": admin.firestore.FieldValue.increment(current.commissionCents),
                updatedAt: now,
            }, { merge: true });
        });
        released += 1;
    }
    return released;
}
async function createAffiliateWithCode(params) {
    const code = normalizeAffiliateCode(params.code);
    if (!code || code.length < 3)
        throw new Error("INVALID_CODE");
    const affiliateId = params.affiliateId.trim();
    if (!affiliateId)
        throw new Error("INVALID_CODE");
    const now = admin.firestore.Timestamp.now();
    const commissionRate = params.commissionRate ?? exports.AFFILIATE_COMMISSION_RATE;
    const status = params.status ?? "active";
    const affiliateRef = db().collection("affiliates").doc(affiliateId);
    const codeRef = db().collection("affiliateCodes").doc(code);
    await db().runTransaction(async (transaction) => {
        const existingCode = await transaction.get(codeRef);
        if (existingCode.exists) {
            const owner = existingCode.data()?.affiliateId;
            if (owner && owner !== affiliateId)
                throw new Error("CODE_CONFLICT");
        }
        transaction.set(codeRef, {
            affiliateId,
            affiliateCode: code,
            displayName: params.displayName.slice(0, 80),
            status,
            commissionRate,
            createdAt: now,
            updatedAt: now,
        }, { merge: true });
        transaction.set(affiliateRef, {
            uid: params.uid ?? null,
            displayName: params.displayName.slice(0, 80),
            email: params.email?.slice(0, 120) ?? null,
            status,
            codes: admin.firestore.FieldValue.arrayUnion(code),
            stats: {
                referredCount: 0,
                activeSubscribers: 0,
                pendingCents: 0,
                payableCents: 0,
                paidCents: 0,
                lifetimeCents: 0,
            },
            createdAt: now,
            updatedAt: now,
        }, { merge: true });
    });
    return { affiliateId, code };
}
async function ensureEmailPasswordSignInEnabled() {
    const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    if (!projectId)
        return;
    try {
        const { GoogleAuth } = await Promise.resolve().then(() => __importStar(require("google-auth-library")));
        const auth = new GoogleAuth({
            scopes: ["https://www.googleapis.com/auth/cloud-platform"],
        });
        const client = await auth.getClient();
        const accessToken = await client.getAccessToken();
        const token = accessToken.token;
        if (!token)
            return;
        const url = `https://identitytoolkit.googleapis.com/v2/projects/${projectId}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired`;
        const response = await fetch(url, {
            method: "PATCH",
            headers: {
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                signIn: {
                    email: {
                        enabled: true,
                        passwordRequired: true,
                    },
                },
            }),
        });
        if (!response.ok) {
            const text = await response.text();
            console.warn("[ensureEmailPasswordSignInEnabled]", response.status, text);
        }
    }
    catch (error) {
        console.warn("[ensureEmailPasswordSignInEnabled]", error);
    }
}
async function provisionAffiliateAuthUser(params) {
    const email = params.email.trim().toLowerCase();
    const password = params.password;
    if (!email || !password || password.length < 8) {
        throw new Error("INVALID_AUTH");
    }
    await ensureEmailPasswordSignInEnabled();
    try {
        const created = await admin.auth().createUser({
            email,
            password,
            displayName: params.displayName?.slice(0, 80),
            emailVerified: true,
        });
        return created.uid;
    }
    catch (error) {
        if (error?.code === "auth/email-already-exists") {
            const existing = await admin.auth().getUserByEmail(email);
            await admin.auth().updateUser(existing.uid, {
                password,
                displayName: params.displayName?.slice(0, 80) || existing.displayName,
            });
            return existing.uid;
        }
        throw error;
    }
}
async function linkAffiliateAuthUser(params) {
    const affiliateId = params.affiliateId.trim();
    if (!affiliateId)
        throw new Error("NOT_FOUND");
    const ref = db().collection("affiliates").doc(affiliateId);
    const snap = await ref.get();
    if (!snap.exists)
        throw new Error("NOT_FOUND");
    const email = params.email.trim().toLowerCase();
    const uid = await provisionAffiliateAuthUser({
        email,
        password: params.password,
        displayName: params.displayName || snap.data()?.displayName,
    });
    await ref.set({
        uid,
        email: email.slice(0, 120),
        updatedAt: admin.firestore.Timestamp.now(),
    }, { merge: true });
    return { uid, affiliateId, email };
}
function verifyAffiliateAdmin(req, expectedSecret) {
    const expected = expectedSecret.trim();
    if (!expected)
        throw new Error("INVALID_ADMIN");
    const header = String(req.headers["x-affiliate-admin-secret"] ?? "").trim();
    if (!header || header !== expected)
        throw new Error("INVALID_ADMIN");
}
async function getAffiliateForUid(uid) {
    const snapshot = await db()
        .collection("affiliates")
        .where("uid", "==", uid)
        .limit(1)
        .get();
    if (snapshot.empty)
        return null;
    const doc = snapshot.docs[0];
    return { affiliateId: doc.id, ...doc.data() };
}
function formatMoney(cents, currency = "EUR") {
    const amount = cents / 100;
    try {
        return new Intl.NumberFormat("fr-FR", {
            style: "currency",
            currency,
            maximumFractionDigits: 2,
        }).format(amount);
    }
    catch {
        return `${amount.toFixed(2)} ${currency}`;
    }
}
//# sourceMappingURL=affiliateShared.js.map