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
exports.affiliateLibrary = void 0;
exports.loadClippingCatalog = loadClippingCatalog;
exports.createClippingFormat = createClippingFormat;
exports.addClippingTikTok = addClippingTikTok;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const affiliateShared_1 = require("./affiliateShared");
const affiliateLibraryShared_1 = require("./affiliateLibraryShared");
const clippingSeed_json_1 = __importDefault(require("./clippingSeed.json"));
const referralShared_1 = require("./referralShared");
const FORMATS = () => (0, affiliateShared_1.db)().collection("clippingFormats");
const POSTS = () => (0, affiliateShared_1.db)().collection("clippingPosts");
function seeded() {
    return (0, affiliateLibraryShared_1.seedFormats)(clippingSeed_json_1.default);
}
async function hydrateTikTok(url) {
    try {
        const response = await fetch(`https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`, {
            headers: { Accept: "application/json" },
        });
        if (!response.ok)
            return { title: "", author: "", thumbnail: "" };
        const data = (await response.json());
        return {
            title: String(data.title || "").slice(0, 240),
            author: String(data.author_name || "").slice(0, 80),
            thumbnail: String(data.thumbnail_url || "").slice(0, 500),
        };
    }
    catch {
        return { title: "", author: "", thumbnail: "" };
    }
}
async function loadClippingCatalog() {
    const seed = seeded();
    const [formatSnap, postSnap] = await Promise.all([
        FORMATS().limit(80).get(),
        POSTS().limit(400).get(),
    ]);
    const liveFormats = formatSnap.docs.map((doc) => (0, affiliateLibraryShared_1.liveFormatFromDoc)(doc.id, doc.data()));
    const livePosts = postSnap.docs.map((doc) => {
        const data = doc.data();
        return (0, affiliateLibraryShared_1.livePostFromDoc)(doc.id, data, String(data.formatId || ""));
    });
    return (0, affiliateLibraryShared_1.mergeCatalog)({
        seedFormats: seed.formats,
        seedSpecs: seed.specs,
        liveFormats,
        livePosts,
    });
}
async function createClippingFormat(params) {
    const nameFr = params.nameFr.trim().slice(0, 80);
    const nameEn = (params.nameEn || params.nameFr).trim().slice(0, 80);
    if (nameFr.length < 2)
        throw new Error("INVALID_TEXT");
    const catalog = await loadClippingCatalog();
    let id = (0, affiliateLibraryShared_1.slugFormatId)(nameEn || nameFr);
    if (catalog.formats.some((row) => row.id === id)) {
        id = `${id}-${params.affiliateId.slice(0, 6)}`;
    }
    const specId = String(params.specId || "").trim();
    const spec = catalog.specs.find((item) => item.id === specId);
    await FORMATS()
        .doc(id)
        .set({
        nameFr,
        nameEn,
        formulaFr: params.formulaFr.trim().slice(0, 240),
        formulaEn: (params.formulaEn || params.formulaFr).trim().slice(0, 240),
        specId: spec?.id || "",
        createdBy: params.affiliateId,
        createdByName: params.displayName.slice(0, 80),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return id;
}
async function addClippingTikTok(params) {
    const parsed = (0, affiliateLibraryShared_1.parseTikTokUrl)(params.url);
    if (!parsed)
        throw new Error("INVALID_TEXT");
    const catalog = await loadClippingCatalog();
    const format = catalog.formats.find((row) => row.id === params.formatId);
    if (!format)
        throw new Error("NOT_FOUND");
    if (format.posts.some((post) => post.id === parsed.id || post.url === parsed.url)) {
        throw new Error("CODE_CONFLICT");
    }
    const meta = await hydrateTikTok(parsed.url);
    const hook = (params.hookFr || meta.title || parsed.handle || "TikTok").slice(0, 240);
    const hookEn = (params.hookEn || params.hookFr || meta.title || hook).slice(0, 240);
    const author = meta.author || (parsed.handle ? `@${parsed.handle}` : "TikTok");
    await POSTS()
        .doc(parsed.id)
        .set({
        formatId: format.id,
        url: parsed.url,
        cover: meta.thumbnail,
        hookFr: hook,
        hookEn,
        subject: author,
        author,
        caption: meta.title.slice(0, 500),
        views: 0,
        likes: 0,
        comments: 0,
        shares: 0,
        saves: 0,
        slides: 0,
        addedBy: params.affiliateId,
        addedByName: params.displayName.slice(0, 80),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAtMs: Date.now(),
    });
    return parsed.id;
}
exports.affiliateLibrary = (0, https_1.onRequest)({
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
        const affiliate = await (0, affiliateShared_1.getAffiliateForUid)(uid);
        if (!affiliate) {
            res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
            return;
        }
        const action = String(req.body?.action || "list");
        const displayName = String(affiliate.displayName || "Clipper").slice(0, 80);
        if (action === "list") {
            const catalog = await loadClippingCatalog();
            res.status(200).json({
                ok: true,
                viewerAffiliateId: affiliate.affiliateId,
                specs: catalog.specs,
                formats: catalog.formats.map((row) => (0, affiliateLibraryShared_1.formatPayload)(row, catalog.specs)),
            });
            return;
        }
        if (action === "createFormat") {
            const id = await createClippingFormat({
                affiliateId: affiliate.affiliateId,
                displayName,
                nameFr: String(req.body?.nameFr || req.body?.name_fr || ""),
                nameEn: String(req.body?.nameEn || req.body?.name_en || ""),
                formulaFr: String(req.body?.formulaFr || req.body?.formula_fr || ""),
                formulaEn: String(req.body?.formulaEn || req.body?.formula_en || ""),
                specId: String(req.body?.specId || req.body?.spec_id || ""),
            });
            const catalog = await loadClippingCatalog();
            res.status(200).json({
                ok: true,
                id,
                formats: catalog.formats.map((row) => (0, affiliateLibraryShared_1.formatPayload)(row, catalog.specs)),
                specs: catalog.specs,
            });
            return;
        }
        if (action === "addTikTok") {
            const id = await addClippingTikTok({
                affiliateId: affiliate.affiliateId,
                displayName,
                url: String(req.body?.url || ""),
                formatId: String(req.body?.formatId || req.body?.format_id || ""),
                hookFr: String(req.body?.hookFr || req.body?.hook_fr || ""),
                hookEn: String(req.body?.hookEn || req.body?.hook_en || ""),
            });
            const catalog = await loadClippingCatalog();
            res.status(200).json({
                ok: true,
                id,
                formats: catalog.formats.map((row) => (0, affiliateLibraryShared_1.formatPayload)(row, catalog.specs)),
                specs: catalog.specs,
            });
            return;
        }
        if (action === "deleteTikTok") {
            const id = String(req.body?.id || "").trim();
            if (!id)
                throw new Error("INVALID_TEXT");
            const ref = POSTS().doc(id);
            const snap = await ref.get();
            if (!snap.exists)
                throw new Error("NOT_FOUND");
            if (String(snap.data()?.addedBy || "") !== affiliate.affiliateId) {
                throw new Error("UNAUTHORIZED");
            }
            await ref.delete();
            const catalog = await loadClippingCatalog();
            res.status(200).json({
                ok: true,
                formats: catalog.formats.map((row) => (0, affiliateLibraryShared_1.formatPayload)(row, catalog.specs)),
                specs: catalog.specs,
            });
            return;
        }
        res.status(400).json({ error: "INVALID_TEXT" });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[affiliateLibrary]", message);
        res.status((0, affiliateShared_1.affiliateHttpStatus)(message)).json({ error: message });
    }
});
//# sourceMappingURL=affiliateLibrary.js.map