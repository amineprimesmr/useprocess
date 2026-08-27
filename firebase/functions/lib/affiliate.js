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
exports.affiliateAdminMarkPaid = exports.affiliateAdminListPending = exports.affiliateAdminApprove = exports.affiliateAdminProvisionAuth = exports.affiliateAdminCreate = exports.affiliateDashboard = exports.affiliateSyncProfile = exports.affiliateApply = exports.affiliateRegister = exports.affiliateTrackFunnel = exports.affiliateTrackLink = exports.affiliateResolveCode = exports.affiliatePreparePasswordless = exports.affiliateSetLoginEmail = exports.affiliatePortalHandoffRedeem = exports.affiliatePortalHandoff = exports.affiliateSendLoginEmail = exports.affiliateValidateLoginEmail = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const affiliateShared_1 = require("./affiliateShared");
const affiliateFunnel_1 = require("./affiliateFunnel");
const affiliateAnalytics_1 = require("./affiliateAnalytics");
const referralShared_1 = require("./referralShared");
const affiliateStripe_1 = require("./affiliateStripe");
const affiliateTikTok_1 = require("./affiliateTikTok");
const affiliateLoginEmail_1 = require("./affiliateLoginEmail");
const affiliatePortalHandoff_1 = require("./affiliatePortalHandoff");
const affiliateAdminSecret = (0, params_1.defineSecret)("AFFILIATE_ADMIN_SECRET");
const stripeSecretKey = (0, params_1.defineSecret)("STRIPE_SECRET_KEY");
const processSmtpPassword = (0, params_1.defineSecret)("PROCESS_SMTP_PASSWORD");
function readProcessSmtpPassword() {
    try {
        const fromSecret = String(processSmtpPassword.value() || "").trim();
        if (fromSecret)
            return fromSecret;
    }
    catch {
        /* secret not bound yet */
    }
    return String(process.env.PROCESS_SMTP_PASSWORD || "").trim();
}
function readAffiliateOnboarding(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    const row = raw;
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
function isValidAffiliatePhone(raw) {
    const digits = String(raw || "").replace(/\D/g, "");
    return digits.length >= 8 && digits.length <= 15;
}
exports.affiliateValidateLoginEmail = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 15,
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
        const email = String(req.body?.email ?? "").trim();
        if (!email || !email.includes("@")) {
            res.status(400).json({ error: "INVALID_EMAIL" });
            return;
        }
        if ((0, affiliateShared_1.isAppleRelayEmail)(email)) {
            res.status(409).json({ error: "APPLE_RELAY_EMAIL" });
            return;
        }
        const eligible = await (0, affiliateShared_1.affiliateEmailEligibleForLoginLink)(email);
        if (!eligible) {
            res.status(404).json({ error: "EMAIL_NOT_FOUND" });
            return;
        }
        res.status(200).json({ ok: true });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateValidateLoginEmail]", message);
        res.status(500).json({ error: message });
    }
});
exports.affiliateSendLoginEmail = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [processSmtpPassword],
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
        const email = String(req.body?.email ?? "").trim();
        const continueUrl = String(req.body?.continueUrl ?? "").trim();
        if (!email || !email.includes("@")) {
            res.status(400).json({ error: "INVALID_EMAIL" });
            return;
        }
        // Apple relay addresses bounce hours later — refuse now so the UI can react.
        if ((0, affiliateShared_1.isAppleRelayEmail)(email)) {
            res.status(409).json({ error: "APPLE_RELAY_EMAIL" });
            return;
        }
        const eligible = await (0, affiliateShared_1.affiliateEmailEligibleForLoginLink)(email);
        if (!eligible) {
            res.status(404).json({ error: "EMAIL_NOT_FOUND" });
            return;
        }
        await (0, affiliateShared_1.ensureEmailPasswordSignInEnabled)();
        await (0, affiliateLoginEmail_1.sendAffiliateLoginEmail)({
            email,
            continueUrl,
            smtpPassword: readProcessSmtpPassword(),
        });
        res.status(200).json({ ok: true });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateSendLoginEmail]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
/**
 * The app is already signed in — hand that session to the web portal directly.
 * Removes email (and therefore Apple relay bounces and spam folders) from the
 * critical path for every clipper who opens the portal from the app.
 */
exports.affiliatePortalHandoff = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 15,
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
        const { code, expiresAt } = await (0, affiliatePortalHandoff_1.createPortalHandoff)(uid);
        res.status(200).json({ ok: true, code, expiresAt });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliatePortalHandoff]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
/** Web side of the handoff: burns the one-time code, returns a custom token. */
exports.affiliatePortalHandoffRedeem = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 15,
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
        const code = String(req.body?.code ?? "").trim();
        const token = await (0, affiliatePortalHandoff_1.redeemPortalHandoff)(code);
        res.status(200).json({ ok: true, token });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliatePortalHandoffRedeem]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
/**
 * Lets a signed-in clipper attach a reachable email to their account — the escape
 * hatch for anyone whose only address is an Apple relay one.
 */
exports.affiliateSetLoginEmail = (0, https_1.onRequest)({
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
        const uid = await (0, referralShared_1.verifyFirebaseUser)(req);
        await (0, referralShared_1.verifyAppAttestation)(req);
        const email = String(req.body?.email ?? "").trim().toLowerCase();
        if (!email || !email.includes("@") || email.length > 254) {
            res.status(400).json({ error: "INVALID_EMAIL" });
            return;
        }
        if ((0, affiliateShared_1.isAppleRelayEmail)(email)) {
            res.status(409).json({ error: "APPLE_RELAY_EMAIL" });
            return;
        }
        // Taken by somebody else → refuse rather than silently merging two clippers.
        try {
            const existing = await admin.auth().getUserByEmail(email);
            if (existing.uid !== uid) {
                res.status(409).json({ error: "EMAIL_IN_USE" });
                return;
            }
        }
        catch (error) {
            if (error?.code !== "auth/user-not-found")
                throw error;
        }
        await admin.auth().updateUser(uid, { email, emailVerified: false });
        await (0, affiliateShared_1.ensureEmailPasswordSignInEnabled)();
        const affiliate = await (0, affiliateShared_1.getAffiliateForUid)(uid);
        if (affiliate) {
            await (0, affiliateShared_1.db)().collection("affiliates").doc(affiliate.affiliateId).set({
                email,
                emailUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        res.status(200).json({ ok: true, email });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateSetLoginEmail]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliatePreparePasswordless = (0, https_1.onRequest)({
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
        await (0, affiliateShared_1.ensureEmailPasswordSignInEnabled)();
        res.status(200).json({ ok: true });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliatePreparePasswordless]", message);
        res.status(500).json({ error: message });
    }
});
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
function clientIp(req) {
    const forwarded = String(req.headers?.["x-forwarded-for"] ?? "").split(",")[0].trim();
    return forwarded || String(req.ip || "").trim() || "unknown";
}
exports.affiliateTrackLink = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 15,
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
        const event = String(req.body?.event ?? "view") === "store" ? "store" : "view";
        const result = await (0, affiliateFunnel_1.trackAffiliateLinkEvent)({
            code: String(req.body?.code ?? ""),
            event,
            visitorId: String(req.body?.visitorId ?? ""),
            userAgent: String(req.headers["user-agent"] ?? ""),
            ip: clientIp(req),
        });
        res.status(200).json(result);
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateTrackLink]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateTrackFunnel = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 15,
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
        const event = String(req.body?.event ?? "");
        if (event !== "paywall") {
            res.status(400).json({ error: "INVALID_EVENT" });
            return;
        }
        let uid = null;
        try {
            uid = await (0, referralShared_1.verifyFirebaseUser)(req);
        }
        catch {
            uid = null;
        }
        const result = await (0, affiliateFunnel_1.trackAffiliatePaywall)({
            code: String(req.body?.code ?? ""),
            visitorId: String(req.body?.visitorId ?? ""),
            uid,
        });
        res.status(200).json(result);
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateTrackFunnel]", message);
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
        const phone = String(req.body?.phone ?? "").trim().slice(0, 40);
        const onboarding = readAffiliateOnboarding(req.body?.onboarding);
        if (!displayName) {
            res.status(400).json({ error: "INVALID_TEXT" });
            return;
        }
        let existing = await (0, affiliateShared_1.getAffiliateForUid)(uid);
        if (!existing && email) {
            const byEmail = await (0, affiliateShared_1.getAffiliateByEmail)(email);
            if (byEmail) {
                await (0, affiliateShared_1.linkAffiliateUid)({ affiliateId: byEmail.affiliateId, uid, email });
                existing = { ...byEmail, uid, email: byEmail.email || email };
            }
        }
        if (!existing) {
            existing = await (0, affiliateShared_1.resolveAffiliateForAuthUser)(uid);
        }
        const affiliateId = existing?.affiliateId || uid;
        if (!existing && !isValidAffiliatePhone(phone)) {
            res.status(400).json({ error: "INVALID_PHONE" });
            return;
        }
        if (!existing) {
            await (0, affiliateShared_1.ensureAffiliateProfile)({
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
            let lastError;
            for (let attempt = 0; attempt < 6; attempt += 1) {
                try {
                    const code = requestedCode || (await (0, affiliateShared_1.allocateUniqueAffiliateCode)(displayName));
                    const created = await (0, affiliateShared_1.createAffiliateWithCode)({
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
                }
                catch (error) {
                    lastError = error;
                    if (requestedCode || error?.message !== "CODE_CONFLICT") {
                        throw error;
                    }
                }
            }
            if (!attachedCode && lastError)
                throw lastError;
        }
        if (onboarding || email || phone) {
            await (0, affiliateShared_1.db)()
                .collection("affiliates")
                .doc(affiliateId)
                .set({
                ...(onboarding ? { onboarding } : {}),
                ...(email ? { email: email.slice(0, 120) } : {}),
                ...(phone ? { phone } : {}),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        const fresh = (await (0, affiliateShared_1.resolveAffiliateForAuthUser)(uid)) || (await (0, affiliateShared_1.getAffiliateForUid)(uid));
        const codes = fresh?.codes ?? [];
        const primaryCode = (0, affiliateShared_1.pickPrimaryAffiliateCode)(codes, attachedCode || fresh?.primaryCode, await (0, affiliateShared_1.readOwnedProcessReferralCode)(uid));
        res.status(200).json({
            ok: true,
            affiliateId,
            status: fresh?.status || existing?.status || "active",
            codes,
            primaryCode,
            code: primaryCode,
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
        const displayName = String(req.body?.displayName ?? "").trim();
        const code = String(req.body?.code ?? req.body?.affiliateCode ?? "").trim();
        const affiliate = await (0, affiliateShared_1.resolveAffiliateForAuthUser)(uid);
        if (!affiliate) {
            res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
            return;
        }
        const updated = await (0, affiliateShared_1.updateAffiliateInviteProfile)({
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
    timeoutSeconds: 20,
    memory: "512MiB",
    minInstances: 1,
    concurrency: 40,
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
        const affiliate = await (0, affiliateShared_1.resolveAffiliateForAuthUser)(uid);
        if (!affiliate) {
            res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
            return;
        }
        void (async () => {
            try {
                const processCode = await (0, affiliateShared_1.readOwnedProcessReferralCode)(uid);
                if (!processCode)
                    return;
                const latest = (await (0, affiliateShared_1.resolveAffiliateForAuthUser)(uid)) || affiliate;
                const ownsProcess = Array.isArray(latest.codes) && latest.codes.includes(processCode);
                if (latest.customPrimaryCode) {
                    if (!ownsProcess) {
                        await (0, affiliateShared_1.createAffiliateWithCode)({
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
                    await (0, affiliateShared_1.createAffiliateWithCode)({
                        affiliateId: latest.affiliateId,
                        code: processCode,
                        displayName: latest.displayName,
                        email: latest.email || undefined,
                        uid,
                        status: latest.status,
                        makePrimary: true,
                    });
                }
            }
            catch (syncError) {
                if (syncError?.message !== "CODE_CONFLICT") {
                    console.warn("[affiliateDashboard] process code sync skipped", syncError);
                }
            }
        })();
        void (0, affiliateShared_1.releaseDueAffiliateCommissions)().catch((releaseError) => {
            console.warn("[affiliateDashboard] releaseDue skipped", releaseError);
        });
        const data = affiliate;
        const stats = data.stats ?? {};
        const hasActivity = Boolean(stats.linkViews ||
            stats.storeClicks ||
            stats.referredCount ||
            stats.paywallCount ||
            stats.paidCount ||
            stats.lifetimeCents);
        const extrasPromise = Promise.all([
            (0, affiliateShared_1.db)()
                .collection("affiliateCodes")
                .where("affiliateId", "==", affiliate.affiliateId)
                .limit(20)
                .get(),
            (0, affiliateShared_1.db)()
                .collection("affiliateCommissions")
                .where("affiliateId", "==", affiliate.affiliateId)
                .limit(50)
                .get(),
            (0, affiliateShared_1.db)()
                .collection("affiliatePayouts")
                .where("affiliateId", "==", affiliate.affiliateId)
                .limit(20)
                .get(),
            hasActivity
                ? (0, affiliateFunnel_1.readAffiliateDailySeries)(affiliate.affiliateId, 30)
                : Promise.resolve((0, affiliateAnalytics_1.emptyDailySeries)(30)),
            (0, affiliateTikTok_1.listPublicTikTokAccounts)(affiliate.affiliateId).catch(() => []),
        ]);
        let codes = [];
        let recentCommissions = [];
        let payouts = [];
        let series = (0, affiliateAnalytics_1.emptyDailySeries)(30);
        let tiktokAccounts = [];
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
        }
        catch (extraError) {
            console.warn("[affiliateDashboard] extras skipped", extraError);
        }
        if (!codes.length && Array.isArray(data.codes)) {
            codes = data.codes.map((code) => ({
                code,
                displayName: data.displayName ?? code,
                status: data.status ?? "active",
            }));
        }
        const primaryCode = (0, affiliateShared_1.pickPrimaryAffiliateCode)(codes.map((row) => row.code), data.primaryCode || affiliate.primaryCode, null);
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
            email: data.email ?? affiliate.email ?? null,
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
                apiReady: (0, affiliateTikTok_1.tiktokApiReady)(),
                accounts: tiktokAccounts,
                totals: (0, affiliateTikTok_1.tiktokTotals)(tiktokAccounts),
            },
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
exports.affiliateAdminListPending = (0, https_1.onRequest)({
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
        const snap = await (0, affiliateShared_1.db)()
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
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateAdminListPending]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateAdminMarkPaid = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [affiliateAdminSecret, stripeSecretKey],
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
        const method = String(req.body?.method ?? "stripe").trim();
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
        const payoutRef = (0, affiliateShared_1.db)().collection("affiliatePayouts").doc();
        let stripeTransferId = null;
        if (method === "stripe") {
            const stripeAccountId = String(affiliateData.stripeAccountId ?? "").trim();
            const payoutsEnabled = Boolean(affiliateData.stripePayoutsEnabled);
            if (!stripeAccountId || !payoutsEnabled) {
                res.status(400).json({ error: "STRIPE_NOT_READY" });
                return;
            }
            stripeTransferId = await (0, affiliateStripe_1.createAffiliateStripeTransfer)({
                affiliateId,
                stripeAccountId,
                amountCents,
                currency,
                payoutId: payoutRef.id,
                secret: stripeSecretKey.value(),
            });
        }
        await (0, affiliateShared_1.db)().runTransaction(async (transaction) => {
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
            stripeTransferId,
        });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateAdminMarkPaid]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
//# sourceMappingURL=affiliate.js.map