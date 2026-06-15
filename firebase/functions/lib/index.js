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
exports.coachStream = exports.coachComplete = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const sdk_1 = __importDefault(require("@anthropic-ai/sdk"));
admin.initializeApp();
const anthropicApiKey = (0, params_1.defineSecret)("ANTHROPIC_API_KEY");
function setCors(res) {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
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
function buildMessages(body) {
    const history = (body.history ?? []).map((m) => ({
        role: m.role,
        content: [{ type: "text", text: m.text }],
    }));
    let userContent;
    if (body.imageBase64) {
        userContent = [
            {
                type: "image",
                source: {
                    type: "base64",
                    media_type: "image/jpeg",
                    data: body.imageBase64,
                },
            },
            { type: "text", text: body.userText },
        ];
    }
    else {
        userContent = [{ type: "text", text: body.userText }];
    }
    return [
        ...history,
        { role: "user", content: userContent },
    ];
}
function maxTokensForTask(task, requested) {
    if (requested && requested > 0)
        return Math.min(requested, 4096);
    switch (task) {
        case "dailyBrief":
        case "readinessAnalysis":
            return 400;
        case "bodyScanVision":
            return 450;
        case "programSummary":
            return 800;
        case "bodyScanReport":
            return 1600;
        default:
            return 1200;
    }
}
exports.coachComplete = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [anthropicApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
}, async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const uid = await verifyFirebaseUser(req);
        const body = req.body;
        if (!body?.system || !body?.userText || !body?.model) {
            res.status(400).json({ error: "Missing system, userText or model" });
            return;
        }
        const client = new sdk_1.default({ apiKey: anthropicApiKey.value() });
        const response = await client.messages.create({
            model: body.model,
            max_tokens: maxTokensForTask(body.task ?? "chat", body.maxTokens),
            system: body.system,
            messages: buildMessages(body),
        });
        const text = response.content
            .filter((b) => b.type === "text")
            .map((b) => (b.type === "text" ? b.text : ""))
            .join("\n")
            .trim();
        await admin
            .firestore()
            .collection("users")
            .doc(uid)
            .collection("coachMeta")
            .doc("usage")
            .set({
            lastTask: body.task ?? "chat",
            lastModel: body.model,
            lastCalledAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        res.status(200).json({ text, model: body.model, uid });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        const status = message === "UNAUTHORIZED" ? 401 : 500;
        console.error("[coachComplete]", message);
        res.status(status).json({ error: message });
    }
});
exports.coachStream = (0, https_1.onRequest)({
    invoker: "public",
    cors: true,
    secrets: [anthropicApiKey],
    timeoutSeconds: 180,
    memory: "512MiB",
}, async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const uid = await verifyFirebaseUser(req);
        const body = req.body;
        if (!body?.system || !body?.userText || !body?.model) {
            res.status(400).json({ error: "Missing system, userText or model" });
            return;
        }
        res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
        res.setHeader("Cache-Control", "no-cache, no-transform");
        res.setHeader("Connection", "keep-alive");
        res.flushHeaders?.();
        const client = new sdk_1.default({ apiKey: anthropicApiKey.value() });
        const stream = await client.messages.stream({
            model: body.model,
            max_tokens: maxTokensForTask(body.task ?? "chat", body.maxTokens),
            system: body.system,
            messages: buildMessages(body),
        });
        for await (const event of stream) {
            if (event.type === "content_block_delta" &&
                event.delta.type === "text_delta") {
                const payload = JSON.stringify({
                    type: "delta",
                    text: event.delta.text,
                });
                res.write(`data: ${payload}\n\n`);
            }
        }
        const finalText = (await stream.finalMessage()).content
            .filter((b) => b.type === "text")
            .map((b) => (b.type === "text" ? b.text : ""))
            .join("\n")
            .trim();
        res.write(`data: ${JSON.stringify({ type: "done", text: finalText, model: body.model, uid })}\n\n`);
        res.end();
        await admin
            .firestore()
            .collection("users")
            .doc(uid)
            .collection("coachMeta")
            .doc("usage")
            .set({
            lastTask: "chat_stream",
            lastModel: body.model,
            lastStreamAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (error) {
        const message = error?.message ?? "Unknown error";
        console.error("[coachStream]", message);
        if (!res.headersSent) {
            res.status(message === "UNAUTHORIZED" ? 401 : 500).json({ error: message });
        }
        else {
            res.write(`data: ${JSON.stringify({ type: "error", error: message })}\n\n`);
            res.end();
        }
    }
});
//# sourceMappingURL=index.js.map