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
exports.HANDOFF_TTL_MS = void 0;
exports.createPortalHandoff = createPortalHandoff;
exports.redeemPortalHandoff = redeemPortalHandoff;
const admin = __importStar(require("firebase-admin"));
const node_crypto_1 = require("node:crypto");
const HANDOFF_COLLECTION = "affiliatePortalHandoffs";
/** Short window: the app opens the portal immediately after asking for the code. */
exports.HANDOFF_TTL_MS = 5 * 60 * 1000;
function db() {
    return admin.firestore();
}
/** Only the hash is stored — a Firestore leak must not hand out portal sessions. */
function handoffDocId(code) {
    return (0, node_crypto_1.createHash)("sha256").update(code).digest("hex");
}
/**
 * One-time code the iOS app passes to the web portal instead of an email link.
 * Clippers signed in with Apple "Hide My Email" can never receive that email,
 * so the app hands off its own session rather than routing through SMTP.
 */
async function createPortalHandoff(uid) {
    if (!uid)
        throw new Error("UNAUTHORIZED");
    const code = (0, node_crypto_1.randomBytes)(32).toString("base64url");
    const expiresAtMs = Date.now() + exports.HANDOFF_TTL_MS;
    await db()
        .collection(HANDOFF_COLLECTION)
        .doc(handoffDocId(code))
        .set({
        uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMs),
        usedAt: null,
    });
    void sweepExpiredHandoffs();
    return { code, expiresAt: expiresAtMs };
}
/** Redeems a code exactly once and returns a custom token for signInWithCustomToken. */
async function redeemPortalHandoff(rawCode) {
    const code = String(rawCode || "").trim();
    if (!code)
        throw new Error("HANDOFF_INVALID");
    const ref = db().collection(HANDOFF_COLLECTION).doc(handoffDocId(code));
    const uid = await db().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists)
            throw new Error("HANDOFF_INVALID");
        const data = snap.data();
        if (data.usedAt)
            throw new Error("HANDOFF_INVALID");
        if (!data.uid)
            throw new Error("HANDOFF_INVALID");
        const expiresAtMs = data.expiresAt?.toMillis?.() ?? 0;
        if (!expiresAtMs || expiresAtMs < Date.now())
            throw new Error("HANDOFF_EXPIRED");
        tx.update(ref, { usedAt: admin.firestore.FieldValue.serverTimestamp() });
        return data.uid;
    });
    return admin.auth().createCustomToken(uid);
}
/** Best-effort GC so redeemed/expired codes don't pile up. Never blocks a request. */
async function sweepExpiredHandoffs() {
    try {
        const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - exports.HANDOFF_TTL_MS);
        const stale = await db()
            .collection(HANDOFF_COLLECTION)
            .where("expiresAt", "<", cutoff)
            .limit(20)
            .get();
        if (stale.empty)
            return;
        const batch = db().batch();
        stale.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
    }
    catch (error) {
        console.warn("[affiliatePortalHandoff] sweep failed", error);
    }
}
//# sourceMappingURL=affiliatePortalHandoff.js.map