"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.affiliateMcp = void 0;
const https_1 = require("firebase-functions/v2/https");
const affiliateShared_1 = require("./affiliateShared");
const affiliateLibrary_1 = require("./affiliateLibrary");
const affiliateLibraryShared_1 = require("./affiliateLibraryShared");
const affiliateTikTok_1 = require("./affiliateTikTok");
const PROTOCOL = "2025-03-26";
function mcpCors(res) {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, MCP-Protocol-Version, Last-Event-ID");
    res.set("Access-Control-Expose-Headers", "Mcp-Session-Id");
}
function rpc(id, result) {
    return { jsonrpc: "2.0", id: id ?? null, result };
}
function rpcError(id, code, message) {
    return { jsonrpc: "2.0", id: id ?? null, error: { code, message } };
}
function toolText(data) {
    return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
}
function readBearer(req) {
    const header = String(req.headers.authorization || "");
    if (header.toLowerCase().startsWith("bearer "))
        return header.slice(7).trim();
    return String(req.headers["x-api-key"] || "").trim();
}
async function resolveMcpAffiliate(token) {
    if (!token.startsWith("ss_live_"))
        throw new Error("UNAUTHORIZED");
    const id = (0, affiliateTikTok_1.hashMcpToken)(token);
    const index = await (0, affiliateShared_1.db)().collection("mcpKeyIndex").doc(id).get();
    let affiliateId = String(index.data()?.affiliateId || "").trim();
    if (!affiliateId) {
        const prefix = token.slice(0, 14);
        const snap = await (0, affiliateShared_1.db)().collectionGroup("mcpKeys").where("prefix", "==", prefix).limit(8).get();
        const match = snap.docs.find((doc) => doc.id === id);
        affiliateId = String(match?.ref.parent.parent?.id || "").trim();
        if (affiliateId) {
            await (0, affiliateShared_1.db)().collection("mcpKeyIndex").doc(id).set({
                affiliateId,
                prefix,
            });
        }
    }
    if (!affiliateId)
        throw new Error("UNAUTHORIZED");
    const snap = await (0, affiliateShared_1.db)().collection("affiliates").doc(affiliateId).get();
    if (!snap.exists)
        throw new Error("UNAUTHORIZED");
    const data = snap.data() || {};
    return {
        affiliateId,
        displayName: String(data.displayName || "Clipper").slice(0, 80),
        primaryCode: String(data.primaryCode || (Array.isArray(data.codes) ? data.codes[0] : "") || ""),
        status: String(data.status || "active"),
    };
}
async function callTool(name, args, actor) {
    if (name === "whoami") {
        const studio = await (0, affiliateTikTok_1.loadStudio)(actor.affiliateId);
        return {
            product: "Process clipping",
            displayName: actor.displayName,
            code: actor.primaryCode,
            status: actor.status,
            tiktokAccounts: studio.accounts.length,
            apiReady: studio.apiReady,
        };
    }
    if (name === "list_formats") {
        const catalog = await (0, affiliateLibrary_1.loadClippingCatalog)();
        return {
            count: catalog.formats.length,
            specs: catalog.specs,
            formats: catalog.formats.map((row) => (0, affiliateLibraryShared_1.formatPayload)(row, catalog.specs)),
        };
    }
    if (name === "get_format") {
        const id = String(args.id || "").trim();
        const catalog = await (0, affiliateLibrary_1.loadClippingCatalog)();
        const format = catalog.formats.find((row) => row.id === id);
        if (!format)
            throw new Error("NOT_FOUND");
        return (0, affiliateLibraryShared_1.formatPayload)(format, catalog.specs);
    }
    if (name === "list_tiktoks") {
        const formatId = String(args.format_id || args.formatId || "").trim();
        const catalog = await (0, affiliateLibrary_1.loadClippingCatalog)();
        const posts = catalog.formats
            .filter((row) => !formatId || row.id === formatId)
            .flatMap((row) => row.posts.map((post) => ({ ...post, formatName: row.name })))
            .sort((a, b) => b.views - a.views);
        return { count: posts.length, posts };
    }
    if (name === "create_format") {
        const id = await (0, affiliateLibrary_1.createClippingFormat)({
            affiliateId: actor.affiliateId,
            displayName: actor.displayName,
            nameFr: String(args.name_fr || args.nameFr || ""),
            nameEn: String(args.name_en || args.nameEn || ""),
            formulaFr: String(args.formula_fr || args.formulaFr || ""),
            formulaEn: String(args.formula_en || args.formulaEn || ""),
            specId: String(args.spec_id || args.specId || ""),
        });
        const catalog = await (0, affiliateLibrary_1.loadClippingCatalog)();
        const format = catalog.formats.find((row) => row.id === id);
        return { ok: true, id, format: format ? (0, affiliateLibraryShared_1.formatPayload)(format, catalog.specs) : null };
    }
    if (name === "add_tiktok") {
        const id = await (0, affiliateLibrary_1.addClippingTikTok)({
            affiliateId: actor.affiliateId,
            displayName: actor.displayName,
            url: String(args.url || ""),
            formatId: String(args.format_id || args.formatId || ""),
            hookFr: String(args.hook_fr || args.hookFr || ""),
            hookEn: String(args.hook_en || args.hookEn || ""),
        });
        return { ok: true, id };
    }
    if (name === "list_channels") {
        const studio = await (0, affiliateTikTok_1.loadStudio)(actor.affiliateId);
        return { channels: studio.accounts };
    }
    if (name === "list_posts") {
        const studio = await (0, affiliateTikTok_1.loadStudio)(actor.affiliateId);
        const status = String(args.status || "").trim();
        const posts = status ? studio.posts.filter((row) => row.status === status) : studio.posts;
        return { posts };
    }
    throw new Error("UNKNOWN_TOOL");
}
async function handleRpc(body, actor) {
    const method = String(body?.method || "");
    const id = body?.id;
    const params = body?.params && typeof body.params === "object" ? body.params : {};
    if (method === "initialize") {
        return rpc(id, {
            protocolVersion: PROTOCOL,
            capabilities: { tools: { listChanged: false } },
            serverInfo: { name: "process-clipping", version: "1.0.0" },
            instructions: "Process clipping MCP. You have 100% access to every TikTok format in the library (official + clipper-created). Call list_formats, then get_format for the full spec, hooks, captions, slide structure and example TikToks. Use add_tiktok / create_format to contribute. list_channels and list_posts cover the Automatiser studio.",
        });
    }
    if (method === "notifications/initialized" || method === "notifications/cancelled") {
        return null;
    }
    if (method === "ping") {
        return rpc(id, {});
    }
    if (method === "tools/list") {
        return rpc(id, {
            tools: affiliateLibraryShared_1.MCP_TOOLS.map((tool) => ({
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema,
            })),
        });
    }
    if (method === "tools/call") {
        const name = String(params.name || "");
        const args = params.arguments && typeof params.arguments === "object" ? params.arguments : {};
        try {
            const result = await callTool(name, args, actor);
            return rpc(id, toolText(result));
        }
        catch (error) {
            return rpc(id, {
                content: [{ type: "text", text: JSON.stringify({ error: error?.message || "error" }) }],
                isError: true,
            });
        }
    }
    return rpcError(id, -32601, `Method not found: ${method}`);
}
exports.affiliateMcp = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    timeoutSeconds: 60,
    memory: "512MiB",
}, async (req, res) => {
    mcpCors(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    try {
        const token = readBearer(req);
        const actor = await resolveMcpAffiliate(token);
        if (req.method === "GET") {
            res.status(200).json({
                ok: true,
                name: "process-clipping",
                protocolVersion: PROTOCOL,
                tools: affiliateLibraryShared_1.MCP_TOOLS.map((tool) => tool.name),
            });
            return;
        }
        if (req.method !== "POST") {
            res.status(405).json({ error: "Method not allowed" });
            return;
        }
        const payload = req.body;
        if (Array.isArray(payload)) {
            const replies = [];
            for (const item of payload) {
                const reply = await handleRpc(item, actor);
                if (reply)
                    replies.push(reply);
            }
            res.status(200).json(replies);
            return;
        }
        const reply = await handleRpc(payload, actor);
        if (reply === null) {
            res.status(202).send("");
            return;
        }
        res.status(200).json(reply);
    }
    catch (error) {
        const message = error?.message || "error";
        const status = message === "UNAUTHORIZED" ? 401 : 500;
        res.status(status).json({ error: message });
    }
});
//# sourceMappingURL=affiliateMcp.js.map