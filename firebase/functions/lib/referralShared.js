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
exports.REFERRER_REWARD_ANNUAL = exports.REFERRER_REWARD_SHORT = exports.PREMIUM_ENTITLEMENT = void 0;
exports.db = db;
exports.normalizeReferralCode = normalizeReferralCode;
exports.setCors = setCors;
exports.verifyFirebaseUser = verifyFirebaseUser;
exports.verifyAppAttestation = verifyAppAttestation;
exports.httpStatusForError = httpStatusForError;
exports.resolveReferrerUserId = resolveReferrerUserId;
exports.upsertReferralCode = upsertReferralCode;
exports.registerReferralRecord = registerReferralRecord;
exports.processReferralRewards = processReferralRewards;
const admin = __importStar(require("firebase-admin"));
const revenueCat_1 = require("./revenueCat");
exports.PREMIUM_ENTITLEMENT = "premium";
exports.REFERRER_REWARD_SHORT = "monthly";
exports.REFERRER_REWARD_ANNUAL = "yearly";
function db() {
    return admin.firestore();
}
function normalizeReferralCode(raw) {
    const cleaned = raw.trim().toUpperCase().replace(/\s+/g, "");
    if (!cleaned)
        return cleaned;
    if (cleaned.includes("-")) {
        return cleaned.replace(/[^A-Z0-9-]/g, "");
    }
    const alnum = cleaned.replace(/[^A-Z0-9]/g, "");
    if (alnum.length <= 4)
        return alnum;
    return `${alnum.slice(0, 4)}-${alnum.slice(4)}`;
}
function setCors(res) {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Firebase-AppCheck");
}
async function verifyFirebaseUser(req) {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
        throw new Error("UNAUTHORIZED");
    }
    const token = header.slice("Bearer ".length);
    const decoded = await admin.auth().verifyIdToken(token);
    return decoded.uid;
}
async function verifyAppAttestation(req) {
    const enforceAppCheck = process.env.ENFORCE_APP_CHECK === "true";
    const token = req.header("X-Firebase-AppCheck");
    if (!token) {
        if (enforceAppCheck)
            throw new Error("INVALID_APP_CHECK");
        return;
    }
    try {
        await admin.appCheck().verifyToken(token);
    }
    catch (error) {
        if (enforceAppCheck)
            throw new Error("INVALID_APP_CHECK");
        console.warn("[AppCheck] Invalid token (monitoring mode)", error);
    }
}
function httpStatusForError(message) {
    if (message === "UNAUTHORIZED")
        return 401;
    if (message === "INVALID_APP_CHECK")
        return 401;
    if (message === "INVALID_CODE")
        return 400;
    if (message === "SELF_REFERRAL")
        return 400;
    if (message === "ALREADY_REFERRED")
        return 409;
    if (message === "NOT_REFERRED")
        return 404;
    if (message === "REFERRER_NOT_FOUND")
        return 404;
    if (message === "SUBSCRIPTION_REQUIRED")
        return 402;
    if (message === "ALREADY_REWARDED")
        return 409;
    if (message === "CODE_CONFLICT")
        return 409;
    if (message === "INVALID_TEXT")
        return 400;
    if (message === "RATE_LIMITED")
        return 429;
    if (message === "CRISP_UNAVAILABLE")
        return 503;
    return 500;
}
async function resolveReferrerUserId(code) {
    const normalized = normalizeReferralCode(code);
    if (!normalized)
        return null;
    const snapshot = await db().collection("referralCodes").doc(normalized).get();
    if (!snapshot.exists)
        return null;
    const userId = snapshot.data()?.userId;
    return typeof userId === "string" && userId.length > 0 ? userId : null;
}
async function upsertReferralCode(params) {
    const normalized = normalizeReferralCode(params.referralCode);
    if (!normalized)
        throw new Error("INVALID_CODE");
    const ref = db().collection("referralCodes").doc(normalized);
    await db().runTransaction(async (transaction) => {
        const existing = await transaction.get(ref);
        if (existing.exists) {
            const owner = existing.data()?.userId;
            if (owner && owner !== params.userId) {
                throw new Error("CODE_CONFLICT");
            }
        }
        transaction.set(ref, {
            userId: params.userId,
            displayName: params.displayName.slice(0, 80),
            referralCode: normalized,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    await db()
        .collection("users")
        .doc(params.userId)
        .collection("referralMeta")
        .doc("program")
        .set({
        referralCode: normalized,
        displayName: params.displayName.slice(0, 80),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function registerReferralRecord(params) {
    if (params.referrerUserId === params.referredUserId) {
        throw new Error("SELF_REFERRAL");
    }
    const referredMetaRef = db()
        .collection("users")
        .doc(params.referredUserId)
        .collection("referralMeta")
        .doc("referredBy");
    const inviteRef = db()
        .collection("users")
        .doc(params.referrerUserId)
        .collection("referralInvites")
        .doc(params.referredUserId);
    await db().runTransaction(async (transaction) => {
        const existing = await transaction.get(referredMetaRef);
        if (existing.exists) {
            throw new Error("ALREADY_REFERRED");
        }
        const now = admin.firestore.Timestamp.now();
        const invite = {
            referredUserId: params.referredUserId,
            referralCode: params.referralCode,
            displayName: params.referredDisplayName.slice(0, 80),
            invitedAt: now,
            status: "pending",
        };
        transaction.set(referredMetaRef, {
            referralCode: params.referralCode,
            referrerUserId: params.referrerUserId,
            registeredAt: now,
            status: "pending",
        });
        transaction.set(inviteRef, invite);
    });
}
async function referrerRewardDuration(referrerUserId, secretKey) {
    try {
        const subscriber = await (0, revenueCat_1.fetchSubscriber)(referrerUserId, secretKey);
        const productId = (0, revenueCat_1.activePremiumProductId)(subscriber, exports.PREMIUM_ENTITLEMENT);
        return (0, revenueCat_1.isAnnualProduct)(productId)
            ? exports.REFERRER_REWARD_ANNUAL
            : exports.REFERRER_REWARD_SHORT;
    }
    catch (error) {
        console.warn("[referral] Could not resolve referrer plan, defaulting to monthly", error);
        return exports.REFERRER_REWARD_SHORT;
    }
}
async function claimReferralReward(referredUserId) {
    const referredMetaRef = db()
        .collection("users")
        .doc(referredUserId)
        .collection("referralMeta")
        .doc("referredBy");
    const claimed = await db().runTransaction(async (transaction) => {
        const referredMeta = await transaction.get(referredMetaRef);
        if (!referredMeta.exists) {
            throw new Error("NOT_REFERRED");
        }
        const meta = referredMeta.data() ?? {};
        if (meta.status === "accepted") {
            throw new Error("ALREADY_REWARDED");
        }
        if (meta.status === "processing") {
            const started = meta.processingAt?.toMillis?.();
            if (started && Date.now() - started < 120_000) {
                throw new Error("ALREADY_REWARDED");
            }
        }
        const referrerUserId = meta.referrerUserId;
        const referralCode = meta.referralCode;
        if (!referrerUserId || !referralCode) {
            throw new Error("NOT_REFERRED");
        }
        transaction.set(referredMetaRef, {
            status: "processing",
            processingAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        return { referrerUserId, referralCode };
    });
    return { ...claimed, referredMetaRef };
}
async function revertReferralClaim(referredMetaRef) {
    await referredMetaRef.set({
        status: "pending",
        processingAt: admin.firestore.FieldValue.delete(),
    }, { merge: true });
}
async function processReferralRewards(params) {
    const claim = await claimReferralReward(params.referredUserId);
    let referrerDuration;
    try {
        const subscriber = await (0, revenueCat_1.fetchSubscriber)(params.referredUserId, params.secretKey);
        if (!(0, revenueCat_1.hasPaidPremium)(subscriber, exports.PREMIUM_ENTITLEMENT)) {
            throw new Error("SUBSCRIPTION_REQUIRED");
        }
        referrerDuration = await referrerRewardDuration(claim.referrerUserId, params.secretKey);
    }
    catch (error) {
        await revertReferralClaim(claim.referredMetaRef);
        throw error;
    }
    try {
        await (0, revenueCat_1.grantPromotionalEntitlement)(claim.referrerUserId, exports.PREMIUM_ENTITLEMENT, referrerDuration, params.secretKey);
    }
    catch (error) {
        await revertReferralClaim(claim.referredMetaRef);
        throw error;
    }
    const now = admin.firestore.Timestamp.now();
    const inviteRef = db()
        .collection("users")
        .doc(claim.referrerUserId)
        .collection("referralInvites")
        .doc(params.referredUserId);
    const acceptedPayload = {
        status: "accepted",
        acceptedAt: now,
        inviteeRewardDuration: null,
        referrerRewardDuration: referrerDuration,
    };
    try {
        await db().runTransaction(async (transaction) => {
            transaction.set(claim.referredMetaRef, acceptedPayload, { merge: true });
            transaction.set(inviteRef, acceptedPayload, { merge: true });
            transaction.set(db()
                .collection("users")
                .doc(claim.referrerUserId)
                .collection("referralMeta")
                .doc("program"), {
                acceptedCount: admin.firestore.FieldValue.increment(1),
                pendingCount: admin.firestore.FieldValue.increment(-1),
                lastRewardAt: now,
            }, { merge: true });
        });
    }
    catch (error) {
        console.error("[referral] granted referrer time but failed to persist", error);
        await claim.referredMetaRef.set(acceptedPayload, { merge: true });
        await inviteRef.set(acceptedPayload, { merge: true });
    }
    return { referrerReward: referrerDuration };
}
//# sourceMappingURL=referralShared.js.map