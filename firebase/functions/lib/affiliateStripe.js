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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.affiliateStripeWebhook = exports.affiliateStripeConnectDashboard = exports.affiliateStripeConnectSync = exports.affiliateStripeConnectStart = void 0;
exports.readStripeConnectSnapshot = readStripeConnectSnapshot;
exports.createAffiliateStripeTransfer = createAffiliateStripeTransfer;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const stripe_1 = __importDefault(require("stripe"));
const affiliateShared_1 = require("./affiliateShared");
const referralShared_1 = require("./referralShared");
const stripeSecretKey = (0, params_1.defineSecret)("STRIPE_SECRET_KEY");
const stripeWebhookSecret = (0, params_1.defineSecret)("STRIPE_CONNECT_WEBHOOK_SECRET");
const AFFILIATE_PORTAL_BASE = "https://useprocess.xyz/clipping";
const AFFILIATE_PRODUCT_DESCRIPTION = "Independent clipper in the Process clipping program. Promotes the Process iOS app on social media and earns a commission on subscriptions.";
function creatorPublicUrl(data) {
    const fromList = Array.isArray(data.onboarding?.tiktokHandles)
        ? data.onboarding.tiktokHandles
        : [];
    const fromSingle = String(data.onboarding?.tiktokHandle || "").split(/\s+/);
    const handle = String([...fromList, ...fromSingle].find(Boolean) || "")
        .trim()
        .replace(/^@+/, "");
    if (handle)
        return `https://www.tiktok.com/@${encodeURIComponent(handle)}`;
    const code = Array.isArray(data.codes) ? String(data.codes[0] || "") : "";
    if (code)
        return `https://useprocess.xyz/join/${encodeURIComponent(code)}`;
    return "https://useprocess.xyz";
}
function individualBusinessProfile(data) {
    return {
        mcc: "7311",
        product_description: AFFILIATE_PRODUCT_DESCRIPTION,
        url: creatorPublicUrl(data),
    };
}
function stripeClient(secret) {
    return new stripe_1.default(secret);
}
function payoutReturnUrl(kind) {
    return `${AFFILIATE_PORTAL_BASE}#/payouts?stripe=${kind}`;
}
async function readStripeConnectSnapshot(accountId, secret) {
    if (!accountId) {
        return {
            accountId: null,
            onboardingComplete: false,
            payoutsEnabled: false,
            detailsSubmitted: false,
            requirementsDue: [],
        };
    }
    const stripe = stripeClient(secret);
    const account = await stripe.accounts.retrieve(accountId);
    const requirementsDue = [
        ...(account.requirements?.currently_due ?? []),
        ...(account.requirements?.past_due ?? []),
    ];
    return {
        accountId,
        onboardingComplete: Boolean(account.details_submitted && account.payouts_enabled),
        payoutsEnabled: Boolean(account.payouts_enabled),
        detailsSubmitted: Boolean(account.details_submitted),
        requirementsDue,
    };
}
async function persistStripeSnapshot(affiliateId, snapshot) {
    await (0, affiliateShared_1.db)()
        .collection("affiliates")
        .doc(affiliateId)
        .set({
        stripeAccountId: snapshot.accountId,
        stripeOnboardingComplete: snapshot.onboardingComplete,
        stripePayoutsEnabled: snapshot.payoutsEnabled,
        stripeDetailsSubmitted: snapshot.detailsSubmitted,
        stripeRequirementsDue: snapshot.requirementsDue,
        payoutMethod: "stripe",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function ensureExpressAccount(params) {
    const affiliateRef = (0, affiliateShared_1.db)().collection("affiliates").doc(params.affiliateId);
    const affiliateSnap = await affiliateRef.get();
    const data = affiliateSnap.data() ?? {};
    const stripe = stripeClient(params.secret);
    if (data.stripeAccountId) {
        return String(data.stripeAccountId);
    }
    const account = await stripe.accounts.create({
        type: "express",
        country: (params.country || "FR").toUpperCase().slice(0, 2),
        email: params.email || undefined,
        business_type: "individual",
        business_profile: individualBusinessProfile(data),
        capabilities: {
            transfers: { requested: true },
        },
        metadata: {
            affiliateId: params.affiliateId,
            uid: params.uid,
            displayName: (params.displayName || "").slice(0, 80),
        },
    });
    await affiliateRef.set({
        stripeAccountId: account.id,
        payoutMethod: "stripe",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return account.id;
}
async function createAffiliateStripeTransfer(params) {
    const stripe = stripeClient(params.secret);
    const transfer = await stripe.transfers.create({
        amount: params.amountCents,
        currency: params.currency.toLowerCase(),
        destination: params.stripeAccountId,
        metadata: {
            affiliateId: params.affiliateId,
            payoutId: params.payoutId,
        },
    });
    return transfer.id;
}
exports.affiliateStripeConnectStart = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [stripeSecretKey],
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
        const secret = stripeSecretKey.value();
        const country = String(req.body?.country ?? "FR").trim() || "FR";
        const accountId = affiliate.stripeAccountId ||
            (await ensureExpressAccount({
                affiliateId: affiliate.affiliateId,
                uid,
                email: affiliate.email ?? undefined,
                displayName: affiliate.displayName,
                country,
                secret,
            }));
        const stripe = stripeClient(secret);
        const link = await stripe.accountLinks.create({
            account: accountId,
            type: "account_onboarding",
            refresh_url: payoutReturnUrl("refresh"),
            return_url: payoutReturnUrl("return"),
            collection_options: { fields: "currently_due" },
        });
        res.status(200).json({ ok: true, url: link.url, accountId });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateStripeConnectStart]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateStripeConnectSync = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [stripeSecretKey],
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
        const affiliate = await (0, affiliateShared_1.resolveAffiliateForAuthUser)(uid);
        if (!affiliate) {
            res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
            return;
        }
        const accountId = affiliate.stripeAccountId;
        if (!accountId) {
            res.status(404).json({ error: "STRIPE_NOT_LINKED" });
            return;
        }
        const snapshot = await readStripeConnectSnapshot(accountId, stripeSecretKey.value());
        await persistStripeSnapshot(affiliate.affiliateId, snapshot);
        res.status(200).json({ ok: true, stripeConnect: snapshot });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateStripeConnectSync]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateStripeConnectDashboard = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [stripeSecretKey],
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
        const accountId = affiliate.stripeAccountId;
        if (!accountId) {
            res.status(404).json({ error: "STRIPE_NOT_LINKED" });
            return;
        }
        const stripe = stripeClient(stripeSecretKey.value());
        const loginLink = await stripe.accounts.createLoginLink(accountId);
        res.status(200).json({ ok: true, url: loginLink.url });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateStripeConnectDashboard]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
exports.affiliateStripeWebhook = (0, https_1.onRequest)({
    invoker: "public",
    cors: false,
    secrets: [stripeSecretKey, stripeWebhookSecret],
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).send("Method not allowed");
        return;
    }
    try {
        const stripe = stripeClient(stripeSecretKey.value());
        const signature = req.headers["stripe-signature"];
        if (!signature || typeof signature !== "string") {
            res.status(400).send("Missing stripe-signature");
            return;
        }
        const event = stripe.webhooks.constructEvent(req.rawBody, signature, stripeWebhookSecret.value());
        if (event.type === "account.updated") {
            const account = event.data.object;
            const affiliateId = account.metadata?.affiliateId;
            if (affiliateId) {
                const snapshot = await readStripeConnectSnapshot(account.id, stripeSecretKey.value());
                await persistStripeSnapshot(affiliateId, snapshot);
            }
        }
        res.status(200).json({ received: true });
    }
    catch (error) {
        console.error("[affiliateStripeWebhook]", error?.message ?? error);
        res.status(400).send(`Webhook error: ${error?.message ?? "unknown"}`);
    }
});
//# sourceMappingURL=affiliateStripe.js.map