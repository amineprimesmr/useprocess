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
exports.REFERRAL_CODE_LENGTH = exports.PREMIUM_ENTITLEMENT = void 0;
exports.db = db;
exports.normalizeReferralCode = normalizeReferralCode;
exports.isValidReferralCode = isValidReferralCode;
exports.setCors = setCors;
exports.verifyFirebaseUser = verifyFirebaseUser;
exports.verifyAppAttestation = verifyAppAttestation;
exports.httpStatusForError = httpStatusForError;
exports.resolveReferrerUserId = resolveReferrerUserId;
exports.upsertReferralCode = upsertReferralCode;
exports.registerReferralRecord = registerReferralRecord;
const admin = __importStar(require("firebase-admin"));
exports.PREMIUM_ENTITLEMENT = "premium";
function db() {
    return admin.firestore();
}
exports.REFERRAL_CODE_LENGTH = 5;
function normalizeReferralCode(raw) {
    const alnum = String(raw || "")
        .trim()
        .toUpperCase()
        .replace(/\s+/g, "")
        .replace(/[^A-Z0-9]/g, "");
    return alnum.slice(0, exports.REFERRAL_CODE_LENGTH);
}
function isValidReferralCode(raw) {
    return normalizeReferralCode(raw).length === exports.REFERRAL_CODE_LENGTH;
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
    if (!isValidReferralCode(normalized))
        return null;
    const snapshot = await db().collection("referralCodes").doc(normalized).get();
    if (!snapshot.exists)
        return null;
    const userId = snapshot.data()?.userId;
    return typeof userId === "string" && userId.length > 0 ? userId : null;
}
async function upsertReferralCode(params) {
    const normalized = normalizeReferralCode(params.referralCode);
    if (!isValidReferralCode(normalized))
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
        stats: {
            pendingCents: 0,
            payableCents: 0,
            paidCents: 0,
            lifetimeCents: 0,
            activeSubscribers: 0,
        },
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
//# sourceMappingURL=referralShared.js.map