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
exports.referralDashboard = exports.referralRegister = exports.referralSyncProgram = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const referralShared_1 = require("./referralShared");
exports.referralSyncProgram = (0, https_1.onRequest)({
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
        const referralCode = (0, referralShared_1.normalizeReferralCode)(String(req.body?.referralCode ?? ""));
        const displayName = String(req.body?.displayName ?? "").trim();
        if (!(0, referralShared_1.isValidReferralCode)(referralCode) || (0, referralShared_1.isReservedLifetimePassCode)(referralCode)) {
            res.status(400).json({ error: "INVALID_CODE" });
            return;
        }
        await (0, referralShared_1.upsertReferralCode)({
            userId: uid,
            referralCode,
            displayName: displayName || "Member",
        });
        res.status(200).json({ ok: true, referralCode });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[referralSyncProgram]", message);
        res.status((0, referralShared_1.httpStatusForError)(message)).json({ error: message });
    }
});
exports.referralRegister = (0, https_1.onRequest)({
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
        const referralCode = (0, referralShared_1.normalizeReferralCode)(String(req.body?.referralCode ?? ""));
        const displayName = String(req.body?.displayName ?? "").trim();
        if (!(0, referralShared_1.isValidReferralCode)(referralCode) || (0, referralShared_1.isReservedLifetimePassCode)(referralCode)) {
            res.status(400).json({ error: "INVALID_CODE" });
            return;
        }
        const referrerUserId = await (0, referralShared_1.resolveReferrerUserId)(referralCode);
        if (!referrerUserId) {
            res.status(404).json({ error: "REFERRER_NOT_FOUND" });
            return;
        }
        await (0, referralShared_1.registerReferralRecord)({
            referrerUserId,
            referredUserId: uid,
            referralCode,
            referredDisplayName: displayName || "Member",
        });
        await (0, referralShared_1.db)()
            .collection("users")
            .doc(referrerUserId)
            .collection("referralMeta")
            .doc("program")
            .set({
            pendingCount: admin.firestore.FieldValue.increment(1),
        }, { merge: true });
        res.status(200).json({ ok: true, referralCode, referrerUserId });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[referralRegister]", message);
        res.status((0, referralShared_1.httpStatusForError)(message)).json({ error: message });
    }
});
exports.referralDashboard = (0, https_1.onRequest)({
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
        const { fetchReferralProgramDashboard } = await Promise.resolve().then(() => __importStar(require("./referralShared")));
        const dashboard = await fetchReferralProgramDashboard(uid);
        res.status(200).json(dashboard);
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[referralDashboard]", message);
        res.status((0, referralShared_1.httpStatusForError)(message)).json({ error: message });
    }
});
//# sourceMappingURL=referral.js.map