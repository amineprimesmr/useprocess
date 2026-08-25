"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MCP_TOOLS = exports.CLIPPING_SITE = void 0;
exports.parseTikTokUrl = parseTikTokUrl;
exports.slugFormatId = slugFormatId;
exports.seedFormats = seedFormats;
exports.livePostFromDoc = livePostFromDoc;
exports.liveFormatFromDoc = liveFormatFromDoc;
exports.mergeCatalog = mergeCatalog;
exports.formatPayload = formatPayload;
exports.CLIPPING_SITE = "https://useprocess.xyz";
const TIKTOK_POST = /(?:https?:\/\/)?(?:www\.|m\.)?tiktok\.com\/@([A-Za-z0-9._]+)\/(?:photo|video)\/(\d+)/i;
function text(fr, en) {
    const french = String(fr || "").trim().slice(0, 240);
    const english = String(en || fr || "").trim().slice(0, 240);
    return { fr: french, en: english || french };
}
function num(value) {
    const n = Number(value);
    return Number.isFinite(n) ? Math.max(0, Math.round(n)) : 0;
}
function absAsset(src) {
    const value = String(src || "").trim();
    if (!value)
        return "";
    if (/^https?:\/\//i.test(value))
        return value;
    if (value.startsWith("/"))
        return `${exports.CLIPPING_SITE}${value}`;
    return value;
}
function parseTikTokUrl(raw) {
    const value = String(raw || "").trim();
    if (!value)
        return null;
    const match = value.match(TIKTOK_POST);
    if (match) {
        const handle = match[1];
        const id = match[2];
        const kind = /\/photo\//i.test(value) ? "photo" : "video";
        return {
            handle,
            id,
            url: `https://www.tiktok.com/@${handle}/${kind}/${id}`,
        };
    }
    try {
        const parsed = new URL(value.startsWith("http") ? value : `https://${value}`);
        if (!/(^|\.)tiktok\.com$/i.test(parsed.hostname))
            return null;
        const id = `ext_${Buffer.from(parsed.href).toString("base64url").slice(0, 24)}`;
        return { url: parsed.href.slice(0, 500), id, handle: "" };
    }
    catch {
        return null;
    }
}
function slugFormatId(name) {
    const slug = String(name || "")
        .normalize("NFKD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 40);
    return slug || `fmt-${Date.now().toString(36)}`;
}
function seedFormats(seed) {
    const specs = (seed.FORMAT_SPECS || []).map((row) => ({
        id: String(row.id || ""),
        name: text(row.name?.fr, row.name?.en),
        canvas: String(row.canvas || ""),
        when: text(row.when?.fr, row.when?.en),
        hook: text(row.hook?.fr, row.hook?.en),
        caption: text(row.caption?.fr, row.caption?.en),
        fatal: text(row.fatal?.fr, row.fatal?.en),
        slides: Array.isArray(row.slides)
            ? row.slides.map((slide) => ({
                src: absAsset(slide.src),
                fr: String(slide.fr || ""),
                en: String(slide.en || slide.fr || ""),
            }))
            : [],
        structure: Array.isArray(row.structure)
            ? row.structure.map((item) => text(item.fr, item.en))
            : [],
    }));
    const formats = (seed.FORMAT_LIBRARY || []).map((row) => {
        const id = String(row.id || "").trim();
        return {
            id,
            specId: String(row.specId || ""),
            name: text(row.name?.fr, row.name?.en),
            formula: text(row.formula?.fr, row.formula?.en),
            official: true,
            createdByName: "Process",
            posts: Array.isArray(row.posts)
                ? row.posts.map((post) => seedPost(id, post))
                : [],
        };
    });
    return { formats, specs };
}
function seedPost(formatId, post) {
    return {
        id: String(post.id || ""),
        formatId,
        url: String(post.url || ""),
        cover: absAsset(post.cover),
        hook: text(post.hook?.fr, post.hook?.en),
        subject: text(post.subject?.fr, post.subject?.en),
        caption: String(post.caption || "").slice(0, 500),
        createdAt: num(post.createdAt),
        slides: num(post.slides),
        views: num(post.views),
        likes: num(post.likes),
        comments: num(post.comments),
        shares: num(post.shares),
        saves: num(post.saves),
        official: true,
        addedByName: "Process",
    };
}
function livePostFromDoc(id, data, formatId) {
    return {
        id,
        formatId,
        url: String(data.url || ""),
        cover: absAsset(String(data.cover || "")),
        hook: text(data.hookFr || data.hook, data.hookEn || data.hook),
        subject: text(data.subject || data.author || "", data.subject || data.author || ""),
        caption: String(data.caption || "").slice(0, 500),
        createdAt: num(data.createdAtMs || data.createdAt),
        slides: num(data.slides),
        views: num(data.views),
        likes: num(data.likes),
        comments: num(data.comments),
        shares: num(data.shares),
        saves: num(data.saves),
        official: false,
        addedByName: String(data.addedByName || "Clipper").slice(0, 80),
    };
}
function liveFormatFromDoc(id, data) {
    return {
        id,
        specId: String(data.specId || ""),
        name: text(data.nameFr || data.name, data.nameEn || data.name),
        formula: text(data.formulaFr || data.formula, data.formulaEn || data.formula),
        official: false,
        createdByName: String(data.createdByName || "Clipper").slice(0, 80),
        posts: [],
    };
}
function mergeCatalog(params) {
    const byId = new Map();
    for (const row of params.seedFormats) {
        byId.set(row.id, { ...row, posts: [...row.posts] });
    }
    for (const row of params.liveFormats) {
        if (byId.has(row.id))
            continue;
        byId.set(row.id, { ...row, posts: [] });
    }
    for (const post of params.livePosts) {
        const format = byId.get(post.formatId);
        if (!format)
            continue;
        if (format.posts.some((item) => item.id === post.id || item.url === post.url))
            continue;
        format.posts.push(post);
    }
    const formats = [...byId.values()].map((row) => ({
        ...row,
        posts: [...row.posts].sort((a, b) => b.views - a.views || b.likes - a.likes),
    }));
    formats.sort((a, b) => {
        const av = a.posts.reduce((sum, post) => sum + post.views, 0);
        const bv = b.posts.reduce((sum, post) => sum + post.views, 0);
        return bv - av;
    });
    return { formats, specs: params.seedSpecs };
}
function formatPayload(format, specs) {
    const spec = specs.find((item) => item.id && item.id === format.specId) || null;
    return {
        id: format.id,
        specId: format.specId || null,
        official: format.official,
        createdByName: format.createdByName,
        name: format.name,
        formula: format.formula,
        postCount: format.posts.length,
        views: format.posts.reduce((sum, post) => sum + post.views, 0),
        likes: format.posts.reduce((sum, post) => sum + post.likes, 0),
        spec,
        posts: format.posts,
    };
}
exports.MCP_TOOLS = [
    {
        name: "whoami",
        description: "Return the clipper workspace: display name, invite code, and TikTok connection count.",
        inputSchema: { type: "object", properties: {} },
    },
    {
        name: "list_formats",
        description: "List EVERY clipping format in the Process library — official Process formats and clipper-created ones. Includes structure specs, post counts, and view totals. Call this before creating or scheduling a TikTok.",
        inputSchema: { type: "object", properties: {} },
    },
    {
        name: "get_format",
        description: "Return 100% of one format: name, formula, slide structure, hook, caption, fatal mistakes, example slide images, and every TikTok in that format (URLs, covers, stats).",
        inputSchema: {
            type: "object",
            properties: { id: { type: "string", description: "Format id from list_formats" } },
            required: ["id"],
        },
    },
    {
        name: "list_tiktoks",
        description: "List every TikTok in the shared library (official + clipper-added). Filter with format_id. Sorted by views.",
        inputSchema: {
            type: "object",
            properties: {
                format_id: { type: "string", description: "Optional format id" },
            },
        },
    },
    {
        name: "create_format",
        description: "Create a new shared format in the Process TikToks library. Other clippers and MCP agents see it immediately.",
        inputSchema: {
            type: "object",
            properties: {
                name_fr: { type: "string" },
                name_en: { type: "string" },
                formula_fr: { type: "string" },
                formula_en: { type: "string" },
                spec_id: { type: "string", description: "Optional official spec 01-05 to attach" },
            },
            required: ["name_fr", "name_en"],
        },
    },
    {
        name: "add_tiktok",
        description: "Add a public TikTok URL to a format in the shared library. Hydrates cover/title via oEmbed when possible.",
        inputSchema: {
            type: "object",
            properties: {
                url: { type: "string" },
                format_id: { type: "string" },
                hook_fr: { type: "string" },
                hook_en: { type: "string" },
            },
            required: ["url", "format_id"],
        },
    },
    {
        name: "list_channels",
        description: "List TikTok accounts connected in Automatiser.",
        inputSchema: { type: "object", properties: {} },
    },
    {
        name: "list_posts",
        description: "List draft, scheduled, or published posts in the Automatiser calendar.",
        inputSchema: {
            type: "object",
            properties: { status: { type: "string", enum: ["draft", "scheduled", "published"] } },
        },
    },
];
//# sourceMappingURL=affiliateLibraryShared.js.map