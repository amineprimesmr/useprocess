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
exports.trackAffiliateLinkEvent = trackAffiliateLinkEvent;
exports.trackAffiliatePaywall = trackAffiliatePaywall;
exports.readAffiliateDailySeries = readAffiliateDailySeries;
const admin = __importStar(require("firebase-admin"));
const affiliateAnalytics_1 = require("./affiliateAnalytics");
const affiliateShared_1 = require("./affiliateShared");
const CLICK_BUDGET_PER_IP_HOUR = 40;
async function allowClickBudget(ip) {
    const normalized = String(ip || "").trim();
    if (!normalized || normalized === "unknown")
        return true;
    const ref = (0, affiliateShared_1.db)().collection("affiliateClickBudget").doc(`${(0, affiliateAnalytics_1.hashKey)(normalized)}_${(0, affiliateAnalytics_1.utcHourKey)()}`);
    const next = await (0, affiliateShared_1.db)().runTransaction(async (transaction) => {
        const snap = await transaction.get(ref);
        const n = Number(snap.data()?.n ?? 0) + 1;
        transaction.set(ref, { n, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        return n;
    });
    return next <= CLICK_BUDGET_PER_IP_HOUR;
}
async function trackAffiliateLinkEvent(params) {
    if ((0, affiliateAnalytics_1.isLikelyBotUserAgent)(params.userAgent || "")) {
        return { ok: true, counted: false, reason: "bot" };
    }
    const visitorId = (0, affiliateAnalytics_1.sanitizeVisitorId)(params.visitorId);
    if (visitorId.length < 8) {
        return { ok: true, counted: false, reason: "invalid_visitor" };
    }
    const resolved = await (0, affiliateShared_1.resolveAffiliateByCode)(params.code);
    if (!resolved) {
        return { ok: true, counted: false, reason: "not_found" };
    }
    const allowed = await allowClickBudget(params.ip || "");
    if (!allowed) {
        return { ok: true, counted: false, reason: "rate_limited" };
    }
    const event = params.event === "store" ? "store" : "view";
    const statField = event === "store" ? "storeClicks" : "linkViews";
    const dailyField = event === "store" ? "storeClicks" : "linkViews";
    const day = (0, affiliateAnalytics_1.utcDayKey)();
    const sessionRef = (0, affiliateShared_1.db)()
        .collection("affiliates")
        .doc(resolved.affiliateId)
        .collection(event === "store" ? "storeSessions" : "linkSessions")
        .doc(`${day}_${visitorId}`);
    const affiliateRef = (0, affiliateShared_1.db)().collection("affiliates").doc(resolved.affiliateId);
    let counted = false;
    await (0, affiliateShared_1.db)().runTransaction(async (transaction) => {
        const existing = await transaction.get(sessionRef);
        if (existing.exists)
            return;
        const now = admin.firestore.Timestamp.now();
        transaction.set(sessionRef, {
            visitorId,
            event,
            createdAt: now,
        });
        transaction.set(affiliateRef, {
            [`stats.${statField}`]: admin.firestore.FieldValue.increment(1),
            updatedAt: now,
        }, { merge: true });
        (0, affiliateShared_1.bumpAffiliateDaily)(transaction, resolved.affiliateId, { [dailyField]: 1 }, now);
        counted = true;
    });
    return { ok: true, counted };
}
async function trackAffiliatePaywall(params) {
    const visitorId = (0, affiliateAnalytics_1.sanitizeVisitorId)(params.visitorId);
    if (visitorId.length < 8) {
        return { ok: true, counted: false, reason: "invalid_visitor" };
    }
    const resolved = await (0, affiliateShared_1.resolveAffiliateByCode)(params.code);
    if (!resolved) {
        return { ok: true, counted: false, reason: "not_found" };
    }
    const uid = String(params.uid || "").trim();
    const funnelCol = (0, affiliateShared_1.db)()
        .collection("affiliates")
        .doc(resolved.affiliateId)
        .collection("funnel");
    const visitorRef = funnelCol.doc(`paywall_v_${visitorId}`);
    const uidRef = uid ? funnelCol.doc(`paywall_u_${uid}`) : null;
    const affiliateRef = (0, affiliateShared_1.db)().collection("affiliates").doc(resolved.affiliateId);
    let counted = false;
    await (0, affiliateShared_1.db)().runTransaction(async (transaction) => {
        const visitorSnap = await transaction.get(visitorRef);
        const uidSnap = uidRef ? await transaction.get(uidRef) : null;
        if (visitorSnap.exists || uidSnap?.exists)
            return;
        const now = admin.firestore.Timestamp.now();
        const payload = {
            event: "paywall",
            visitorId,
            uid: uid || null,
            createdAt: now,
        };
        transaction.set(visitorRef, payload);
        if (uidRef)
            transaction.set(uidRef, payload);
        transaction.set(affiliateRef, {
            "stats.paywallCount": admin.firestore.FieldValue.increment(1),
            updatedAt: now,
        }, { merge: true });
        (0, affiliateShared_1.bumpAffiliateDaily)(transaction, resolved.affiliateId, { paywalls: 1 }, now);
        counted = true;
    });
    return { ok: true, counted };
}
async function readAffiliateDailySeries(affiliateId, days = 30) {
    const series = (0, affiliateAnalytics_1.emptyDailySeries)(days);
    const keys = (0, affiliateAnalytics_1.lastNDayKeys)(days);
    const start = keys[0];
    const end = keys[keys.length - 1];
    if (!start || !end)
        return series;
    const snap = await (0, affiliateShared_1.db)()
        .collection("affiliates")
        .doc(affiliateId)
        .collection("daily")
        .where("day", ">=", start)
        .where("day", "<=", end)
        .get();
    const byDay = new Map(snap.docs.map((doc) => [doc.id, doc.data() || {}]));
    keys.forEach((day, index) => {
        const row = { ...affiliateAnalytics_1.EMPTY_DAILY_COUNTS, ...(byDay.get(day) || {}) };
        series.linkViews[index] = Number(row.linkViews || 0);
        series.storeClicks[index] = Number(row.storeClicks || 0);
        series.attributions[index] = Number(row.attributions || 0);
        series.paywalls[index] = Number(row.paywalls || 0);
        series.sales[index] = Number(row.sales || 0);
        series.earningsCents[index] = Number(row.earningsCents || 0);
    });
    return series;
}
//# sourceMappingURL=affiliateFunnel.js.map