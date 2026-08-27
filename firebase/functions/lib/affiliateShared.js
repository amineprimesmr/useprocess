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
exports.commissionFromRevenueCatEvent = exports.APPLE_PRIVATE_RELAY_DOMAIN = exports.LIFETIME_PRODUCT_ID = exports.AFFILIATE_NET_FACTOR = exports.AFFILIATE_HOLD_DAYS = exports.AFFILIATE_COMMISSION_RATE = void 0;
exports.db = db;
exports.normalizeAffiliateCode = normalizeAffiliateCode;
exports.isReservedVanityAffiliateCode = isReservedVanityAffiliateCode;
exports.allocateUniqueAffiliateCode = allocateUniqueAffiliateCode;
exports.isAppleRelayEmail = isAppleRelayEmail;
exports.affiliateHttpStatus = affiliateHttpStatus;
exports.affiliateEmailEligibleForLoginLink = affiliateEmailEligibleForLoginLink;
exports.resolveAffiliateByCode = resolveAffiliateByCode;
exports.resolveCodeKind = resolveCodeKind;
exports.commissionDocId = commissionDocId;
exports.bumpAffiliateDaily = bumpAffiliateDaily;
exports.registerAffiliateAttribution = registerAffiliateAttribution;
exports.getAffiliateAttributionForUser = getAffiliateAttributionForUser;
exports.accrueAffiliateCommission = accrueAffiliateCommission;
exports.clawbackAffiliateCommission = clawbackAffiliateCommission;
exports.markAffiliateAttributionChurned = markAffiliateAttributionChurned;
exports.releaseDueAffiliateCommissions = releaseDueAffiliateCommissions;
exports.readOwnedProcessReferralCode = readOwnedProcessReferralCode;
exports.pickPrimaryAffiliateCode = pickPrimaryAffiliateCode;
exports.ensureAffiliateProfile = ensureAffiliateProfile;
exports.createAffiliateWithCode = createAffiliateWithCode;
exports.syncAffiliateCodesDisplayName = syncAffiliateCodesDisplayName;
exports.updateAffiliateInviteProfile = updateAffiliateInviteProfile;
exports.ensureEmailPasswordSignInEnabled = ensureEmailPasswordSignInEnabled;
exports.provisionAffiliateAuthUser = provisionAffiliateAuthUser;
exports.linkAffiliateAuthUser = linkAffiliateAuthUser;
exports.verifyAffiliateAdmin = verifyAffiliateAdmin;
exports.getAffiliateForUid = getAffiliateForUid;
exports.getAffiliateByEmail = getAffiliateByEmail;
exports.linkAffiliateUid = linkAffiliateUid;
exports.resolveAffiliateForAuthUser = resolveAffiliateForAuthUser;
exports.formatMoney = formatMoney;
const admin = __importStar(require("firebase-admin"));
const revenueCat_1 = require("./revenueCat");
const commissionShared_1 = require("./commissionShared");
Object.defineProperty(exports, "LIFETIME_PRODUCT_ID", { enumerable: true, get: function () { return commissionShared_1.LIFETIME_PRODUCT_ID; } });
Object.defineProperty(exports, "commissionFromRevenueCatEvent", { enumerable: true, get: function () { return commissionShared_1.commissionFromRevenueCatEvent; } });
const referralShared_1 = require("./referralShared");
const affiliateAnalytics_1 = require("./affiliateAnalytics");
exports.AFFILIATE_COMMISSION_RATE = commissionShared_1.COMMISSION_RATE;
exports.AFFILIATE_HOLD_DAYS = commissionShared_1.COMMISSION_HOLD_DAYS;
exports.AFFILIATE_NET_FACTOR = commissionShared_1.COMMISSION_NET_FACTOR;
function db() {
    return admin.firestore();
}
const RESERVED_VANITY_AFFILIATE_CODES = new Set([
    "JOIN",
    "GET",
    "APP",
    "ADMIN",
    "API",
    "WWW",
    "FAQ",
    "SUPPORT",
    "LOGIN",
    "APPLY",
    "AUTH",
    "PROGRAM",
    "PROCESS",
    "CLIP",
    "CLIPPER",
    "REF",
    "REFERRAL",
    "INVITE",
    "LINK",
    "CODE",
    "NULL",
    "UNDEFINED",
]);
function normalizeAffiliateCode(raw) {
    return String(raw || "")
        .trim()
        .toUpperCase()
        .replace(/\s+/g, "")
        .replace(/[^A-Z0-9-]/g, "")
        .slice(0, 24);
}
function isReservedVanityAffiliateCode(raw) {
    const code = normalizeAffiliateCode(raw);
    return !code || RESERVED_VANITY_AFFILIATE_CODES.has(code) || (0, referralShared_1.isReservedLifetimePassCode)(code);
}
async function allocateUniqueAffiliateCode(displayName) {
    const letters = normalizeAffiliateCode(String(displayName || "")
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")).replace(/-/g, "");
    const base = (letters.slice(0, 8) || "CLIP").padEnd(3, "X");
    const isFree = async (code) => {
        if (!code || code.length < 3)
            return false;
        if ((0, referralShared_1.isReservedLifetimePassCode)(code))
            return false;
        const snap = await db().collection("affiliateCodes").doc(code).get();
        return !snap.exists;
    };
    if (await isFree(base))
        return base;
    for (let i = 0; i < 40; i += 1) {
        const candidate = normalizeAffiliateCode(`${base.slice(0, 8)}${10 + Math.floor(Math.random() * 90)}`);
        if (await isFree(candidate))
            return candidate;
    }
    const fallback = normalizeAffiliateCode(`P${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`.toUpperCase());
    if (await isFree(fallback))
        return fallback;
    return normalizeAffiliateCode(`P${Math.random().toString(36).slice(2, 10).toUpperCase()}`);
}
exports.APPLE_PRIVATE_RELAY_DOMAIN = "privaterelay.appleid.com";
/**
 * Apple "Hide My Email" relay addresses only accept mail from senders registered in
 * Apple Developer → Sign in with Apple for Email Communication. Anything else is
 * rejected at RCPT TO with `550 5.1.1 unauthorized sender`, hours after we replied OK.
 */
function isAppleRelayEmail(rawEmail) {
    const email = String(rawEmail || "").trim().toLowerCase();
    return email.endsWith(`@${exports.APPLE_PRIVATE_RELAY_DOMAIN}`);
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
    if (message === "NOT_FOUND")
        return 404;
    if (message === "AFFILIATE_INACTIVE")
        return 403;
    if (message === "AFFILIATE_NOT_LINKED")
        return 403;
    if (message === "STRIPE_NOT_LINKED")
        return 404;
    if (message === "STRIPE_NOT_CONFIGURED")
        return 503;
    if (message === "STRIPE_NOT_READY")
        return 400;
    if (message === "CODE_CONFLICT")
        return 409;
    if (message === "INVALID_ADMIN")
        return 401;
    if (message === "INVALID_TEXT")
        return 400;
    if (message === "INVALID_PHONE")
        return 400;
    if (message === "INVALID_PAYOUT")
        return 400;
    if (message === "EMAIL_NOT_FOUND")
        return 404;
    if (message === "INVALID_EMAIL")
        return 400;
    if (message === "SMTP_NOT_CONFIGURED")
        return 503;
    if (message === "INVALID_CONTINUE_URL")
        return 400;
    if (message === "EMAIL_MISMATCH")
        return 409;
    if (message === "APPLE_RELAY_EMAIL")
        return 409;
    if (message === "EMAIL_IN_USE")
        return 409;
    if (message === "HANDOFF_INVALID")
        return 404;
    if (message === "HANDOFF_EXPIRED")
        return 410;
    return 500;
}
/** True when this email can receive a clipper login link (Firebase Auth or affiliate profile). */
async function affiliateEmailEligibleForLoginLink(rawEmail) {
    const trimmed = String(rawEmail || "").trim();
    const email = trimmed.toLowerCase();
    if (!email || !email.includes("@"))
        return false;
    try {
        const user = await admin.auth().getUserByEmail(email);
        if (!user.disabled && user.email?.toLowerCase() === email)
            return true;
    }
    catch (error) {
        if (error?.code !== "auth/user-not-found")
            throw error;
    }
    for (const candidate of [email, trimmed]) {
        const snap = await db()
            .collection("affiliates")
            .where("email", "==", candidate)
            .limit(1)
            .get();
        if (!snap.empty)
            return true;
    }
    return false;
}
async function resolveAffiliateByCode(code) {
    const normalized = normalizeAffiliateCode(code);
    if (!normalized)
        return null;
    if ((0, referralShared_1.isReservedLifetimePassCode)(normalized))
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
    if ((0, referralShared_1.isReservedLifetimePassCode)(code))
        return null;
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
function bumpAffiliateDaily(transaction, affiliateId, patch, now = admin.firestore.Timestamp.now()) {
    const day = (0, affiliateAnalytics_1.utcDayKey)();
    const data = {
        day,
        updatedAt: now,
    };
    for (const [key, value] of Object.entries(patch)) {
        if (typeof value === "number" && value !== 0) {
            data[key] = admin.firestore.FieldValue.increment(value);
        }
    }
    transaction.set(db().collection("affiliates").doc(affiliateId).collection("daily").doc(day), data, { merge: true });
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
        bumpAffiliateDaily(transaction, params.affiliateId, { attributions: 1 }, now);
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
    const attributionRef = affiliateRef.collection("attributions").doc(params.inviteeUid);
    await db().runTransaction(async (transaction) => {
        const attrSnap = await transaction.get(attributionRef);
        const attrData = attrSnap.data() ?? {};
        const isFirstPaid = isInitial && !attrData.firstPaidAt;
        const needsActive = isInitial && attrData.countedAsActive !== true;
        transaction.set(commissionRef, commission);
        transaction.set(affiliateRef, {
            "stats.pendingCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
            "stats.lifetimeCents": admin.firestore.FieldValue.increment(amounts.commissionCents),
            ...(isFirstPaid
                ? { "stats.paidCount": admin.firestore.FieldValue.increment(1) }
                : {}),
            ...(needsActive
                ? { "stats.activeSubscribers": admin.firestore.FieldValue.increment(1) }
                : {}),
            updatedAt: now,
        }, { merge: true });
        transaction.set(attributionRef, {
            lastCommissionAt: now,
            lastProductId: amounts.productId ?? null,
            ...(isFirstPaid ? { firstPaidAt: now } : {}),
            ...(needsActive ? { countedAsActive: true } : {}),
        }, { merge: true });
        bumpAffiliateDaily(transaction, attribution.affiliateId, {
            earningsCents: amounts.commissionCents,
            ...(isFirstPaid ? { sales: 1 } : {}),
        }, now);
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
    const attributionRef = db()
        .collection("affiliates")
        .doc(attribution.affiliateId)
        .collection("attributions")
        .doc(inviteeUid);
    const attrSnap = await attributionRef.get();
    const wasActive = attrSnap.data()?.countedAsActive === true;
    await db()
        .collection("users")
        .doc(inviteeUid)
        .collection("affiliateMeta")
        .doc("referredBy")
        .set({ status: "churned" }, { merge: true });
    await attributionRef.set({
        status: "churned",
        countedAsActive: false,
    }, { merge: true });
    if (!wasActive)
        return;
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
async function readOwnedProcessReferralCode(uid) {
    const program = await db()
        .collection("users")
        .doc(uid)
        .collection("referralMeta")
        .doc("program")
        .get();
    const raw = program.data()?.referralCode;
    if (typeof raw !== "string")
        return null;
    const normalized = (0, referralShared_1.normalizeReferralCode)(raw);
    if (!(0, referralShared_1.isValidReferralCode)(normalized))
        return null;
    const owner = await (0, referralShared_1.resolveReferrerUserId)(normalized);
    return owner === uid ? normalized : null;
}
function pickPrimaryAffiliateCode(codes, stored, processCode) {
    if (processCode && codes.includes(processCode))
        return processCode;
    if (stored && codes.includes(stored))
        return stored;
    const processLike = codes.find((code) => code.length === 5);
    if (processLike)
        return processLike;
    return codes[0] || "";
}
async function ensureAffiliateProfile(params) {
    const affiliateId = params.affiliateId.trim();
    if (!affiliateId)
        throw new Error("INVALID_CODE");
    const affiliateRef = db().collection("affiliates").doc(affiliateId);
    const now = admin.firestore.Timestamp.now();
    const existing = await affiliateRef.get();
    if (existing.exists) {
        await affiliateRef.set({
            displayName: params.displayName.slice(0, 80),
            ...(params.email ? { email: params.email.slice(0, 120) } : {}),
            ...(params.phone ? { phone: params.phone.slice(0, 40) } : {}),
            updatedAt: now,
        }, { merge: true });
        return { affiliateId };
    }
    await affiliateRef.set({
        uid: params.uid ?? null,
        displayName: params.displayName.slice(0, 80),
        email: params.email?.slice(0, 120) ?? null,
        ...(params.phone ? { phone: params.phone.slice(0, 40) } : {}),
        status: params.status ?? "active",
        codes: [],
        stats: {
            referredCount: 0,
            activeSubscribers: 0,
            pendingCents: 0,
            payableCents: 0,
            paidCents: 0,
            lifetimeCents: 0,
            linkViews: 0,
            storeClicks: 0,
            paywallCount: 0,
            paidCount: 0,
        },
        createdAt: now,
        updatedAt: now,
    });
    return { affiliateId };
}
async function createAffiliateWithCode(params) {
    const code = normalizeAffiliateCode(params.code);
    if (!code || code.length < 3)
        throw new Error("INVALID_CODE");
    if ((0, referralShared_1.isReservedLifetimePassCode)(code))
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
        const affiliateSnap = await transaction.get(affiliateRef);
        const currentCodes = Array.isArray(affiliateSnap.data()?.codes)
            ? affiliateSnap.data()?.codes
            : [];
        const nextCodes = params.makePrimary
            ? [code, ...currentCodes.filter((item) => item !== code)]
            : currentCodes.includes(code)
                ? currentCodes
                : [...currentCodes, code];
        const nextPrimary = params.makePrimary || !affiliateSnap.data()?.primaryCode
            ? code
            : String(affiliateSnap.data()?.primaryCode || code);
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
            email: params.email?.slice(0, 120) ?? affiliateSnap.data()?.email ?? null,
            status,
            codes: nextCodes,
            primaryCode: nextPrimary,
            ...(affiliateSnap.exists
                ? {}
                : {
                    stats: {
                        referredCount: 0,
                        activeSubscribers: 0,
                        pendingCents: 0,
                        payableCents: 0,
                        paidCents: 0,
                        lifetimeCents: 0,
                        linkViews: 0,
                        storeClicks: 0,
                        paywallCount: 0,
                        paidCount: 0,
                    },
                }),
            createdAt: affiliateSnap.data()?.createdAt ?? now,
            updatedAt: now,
        }, { merge: true });
    });
    return { affiliateId, code };
}
async function syncAffiliateCodesDisplayName(affiliateId, displayName) {
    const name = displayName.slice(0, 80);
    if (!affiliateId || !name)
        return;
    const snap = await db()
        .collection("affiliateCodes")
        .where("affiliateId", "==", affiliateId)
        .limit(40)
        .get();
    if (snap.empty)
        return;
    const now = admin.firestore.Timestamp.now();
    const batch = db().batch();
    for (const doc of snap.docs) {
        batch.set(doc.ref, { displayName: name, updatedAt: now }, { merge: true });
    }
    await batch.commit();
}
async function updateAffiliateInviteProfile(params) {
    const affiliateRef = db().collection("affiliates").doc(params.affiliateId);
    const snap = await affiliateRef.get();
    if (!snap.exists)
        throw new Error("AFFILIATE_NOT_FOUND");
    const current = snap.data();
    const nextName = (params.displayName || current.displayName || "").trim().slice(0, 80);
    if (!nextName)
        throw new Error("INVALID_TEXT");
    const requested = normalizeAffiliateCode(params.code || "");
    const currentPrimary = String(current.primaryCode || current.codes?.[0] || "");
    if (requested) {
        if (requested.length < 3 || isReservedVanityAffiliateCode(requested)) {
            throw new Error("INVALID_CODE");
        }
        if ((0, referralShared_1.isValidReferralCode)(requested)) {
            const owner = await (0, referralShared_1.resolveReferrerUserId)(requested);
            if (owner && owner !== params.uid)
                throw new Error("CODE_CONFLICT");
        }
        if (requested !== currentPrimary) {
            await createAffiliateWithCode({
                affiliateId: params.affiliateId,
                code: requested,
                displayName: nextName,
                email: params.email || current.email || undefined,
                uid: params.uid,
                status: params.status || current.status,
                makePrimary: true,
            });
            await affiliateRef.set({
                customPrimaryCode: true,
                displayName: nextName,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
    }
    if (nextName !== current.displayName || !requested) {
        await affiliateRef.set({
            displayName: nextName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    await syncAffiliateCodesDisplayName(params.affiliateId, nextName);
    const fresh = await affiliateRef.get();
    const data = fresh.data() || current;
    const codes = Array.isArray(data.codes) ? data.codes : [];
    const primaryCode = pickPrimaryAffiliateCode(codes, data.primaryCode, null);
    return { displayName: data.displayName || nextName, primaryCode, codes };
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
        const url = `https://identitytoolkit.googleapis.com/v2/projects/${projectId}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired,signIn.anonymous.enabled`;
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
                        passwordRequired: false,
                    },
                    anonymous: {
                        enabled: true,
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
    if (!snapshot.empty) {
        const doc = snapshot.docs[0];
        return { affiliateId: doc.id, ...doc.data() };
    }
    const byId = await db().collection("affiliates").doc(uid).get();
    if (!byId.exists)
        return null;
    const data = byId.data();
    return { affiliateId: byId.id, ...data };
}
async function getAffiliateByEmail(rawEmail) {
    const trimmed = String(rawEmail || "").trim();
    const email = trimmed.toLowerCase();
    if (!email || !email.includes("@"))
        return null;
    for (const candidate of [email, trimmed]) {
        const snapshot = await db()
            .collection("affiliates")
            .where("email", "==", candidate)
            .limit(1)
            .get();
        if (!snapshot.empty) {
            const doc = snapshot.docs[0];
            return { affiliateId: doc.id, ...doc.data() };
        }
    }
    return null;
}
/** Attach a Firebase Auth session (new device / email login) to an existing clipper profile. */
async function linkAffiliateUid(params) {
    const affiliateId = params.affiliateId.trim();
    const uid = params.uid.trim();
    if (!affiliateId || !uid)
        throw new Error("NOT_FOUND");
    const ref = db().collection("affiliates").doc(affiliateId);
    const snap = await ref.get();
    if (!snap.exists)
        throw new Error("NOT_FOUND");
    const row = snap.data();
    const nextEmail = params.email?.trim().toLowerCase() || row.email || null;
    if (nextEmail && row.email && row.email.toLowerCase() !== nextEmail) {
        throw new Error("EMAIL_MISMATCH");
    }
    await ref.set({
        uid,
        ...(nextEmail ? { email: nextEmail.slice(0, 120) } : {}),
        updatedAt: admin.firestore.Timestamp.now(),
    }, { merge: true });
}
async function resolveAffiliateForAuthUser(uid) {
    const byUid = await getAffiliateForUid(uid);
    if (byUid)
        return byUid;
    let authEmail = "";
    try {
        const authUser = await admin.auth().getUser(uid);
        authEmail = String(authUser.email || "").trim().toLowerCase();
        if (!authEmail)
            return null;
    }
    catch {
        return null;
    }
    const byEmail = await getAffiliateByEmail(authEmail);
    if (!byEmail)
        return null;
    await linkAffiliateUid({ affiliateId: byEmail.affiliateId, uid, email: authEmail });
    return { ...byEmail, uid, email: byEmail.email || authEmail };
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