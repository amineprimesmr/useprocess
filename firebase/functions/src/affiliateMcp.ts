import { onRequest } from "firebase-functions/v2/https";
import { db } from "./affiliateShared";
import {
  addClippingTikTok,
  createClippingFormat,
  loadClippingCatalog,
} from "./affiliateLibrary";
import { formatPayload, MCP_TOOLS } from "./affiliateLibraryShared";
import { hashMcpToken, loadStudio } from "./affiliateTikTok";

const PROTOCOL = "2025-03-26";

function mcpCors(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization, MCP-Protocol-Version, Last-Event-ID"
  );
  res.set("Access-Control-Expose-Headers", "Mcp-Session-Id");
}

function rpc(id: unknown, result: unknown) {
  return { jsonrpc: "2.0", id: id ?? null, result };
}

function rpcError(id: unknown, code: number, message: string) {
  return { jsonrpc: "2.0", id: id ?? null, error: { code, message } };
}

function toolText(data: unknown) {
  return {
    content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
  };
}

function readBearer(req: any): string {
  const header = String(req.headers.authorization || "");
  if (header.toLowerCase().startsWith("bearer ")) return header.slice(7).trim();
  return String(req.headers["x-api-key"] || "").trim();
}

async function resolveMcpAffiliate(token: string) {
  if (!token.startsWith("ss_live_")) throw new Error("UNAUTHORIZED");
  const id = hashMcpToken(token);
  const index = await db().collection("mcpKeyIndex").doc(id).get();
  let affiliateId = String(index.data()?.affiliateId || "").trim();
  if (!affiliateId) {
    const prefix = token.slice(0, 14);
    const snap = await db().collectionGroup("mcpKeys").where("prefix", "==", prefix).limit(8).get();
    const match = snap.docs.find((doc) => doc.id === id);
    affiliateId = String(match?.ref.parent.parent?.id || "").trim();
    if (affiliateId) {
      await db().collection("mcpKeyIndex").doc(id).set({
        affiliateId,
        prefix,
      });
    }
  }
  if (!affiliateId) throw new Error("UNAUTHORIZED");
  const snap = await db().collection("affiliates").doc(affiliateId).get();
  if (!snap.exists) throw new Error("UNAUTHORIZED");
  const data = snap.data() || {};
  return {
    affiliateId,
    displayName: String(data.displayName || "Clipper").slice(0, 80),
    primaryCode: String(data.primaryCode || (Array.isArray(data.codes) ? data.codes[0] : "") || ""),
    status: String(data.status || "active"),
  };
}

async function callTool(name: string, args: Record<string, unknown>, actor: Awaited<ReturnType<typeof resolveMcpAffiliate>>) {
  if (name === "whoami") {
    const studio = await loadStudio(actor.affiliateId);
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
    const catalog = await loadClippingCatalog();
    return {
      count: catalog.formats.length,
      specs: catalog.specs,
      formats: catalog.formats.map((row) => formatPayload(row, catalog.specs)),
    };
  }

  if (name === "get_format") {
    const id = String(args.id || "").trim();
    const catalog = await loadClippingCatalog();
    const format = catalog.formats.find((row) => row.id === id);
    if (!format) throw new Error("NOT_FOUND");
    return formatPayload(format, catalog.specs);
  }

  if (name === "list_tiktoks") {
    const formatId = String(args.format_id || args.formatId || "").trim();
    const catalog = await loadClippingCatalog();
    const posts = catalog.formats
      .filter((row) => !formatId || row.id === formatId)
      .flatMap((row) => row.posts.map((post) => ({ ...post, formatName: row.name })))
      .sort((a, b) => b.views - a.views);
    return { count: posts.length, posts };
  }

  if (name === "create_format") {
    const id = await createClippingFormat({
      affiliateId: actor.affiliateId,
      displayName: actor.displayName,
      nameFr: String(args.name_fr || args.nameFr || ""),
      nameEn: String(args.name_en || args.nameEn || ""),
      formulaFr: String(args.formula_fr || args.formulaFr || ""),
      formulaEn: String(args.formula_en || args.formulaEn || ""),
      specId: String(args.spec_id || args.specId || ""),
    });
    const catalog = await loadClippingCatalog();
    const format = catalog.formats.find((row) => row.id === id);
    return { ok: true, id, format: format ? formatPayload(format, catalog.specs) : null };
  }

  if (name === "add_tiktok") {
    const id = await addClippingTikTok({
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
    const studio = await loadStudio(actor.affiliateId);
    return { channels: studio.accounts };
  }

  if (name === "list_posts") {
    const studio = await loadStudio(actor.affiliateId);
    const status = String(args.status || "").trim();
    const posts = status ? studio.posts.filter((row) => row.status === status) : studio.posts;
    return { posts };
  }

  throw new Error("UNKNOWN_TOOL");
}

async function handleRpc(body: any, actor: Awaited<ReturnType<typeof resolveMcpAffiliate>>) {
  const method = String(body?.method || "");
  const id = body?.id;
  const params = body?.params && typeof body.params === "object" ? body.params : {};

  if (method === "initialize") {
    return rpc(id, {
      protocolVersion: PROTOCOL,
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: "process-clipping", version: "1.0.0" },
      instructions:
        "Process clipping MCP. You have 100% access to every TikTok format in the library (official + clipper-created). Call list_formats, then get_format for the full spec, hooks, captions, slide structure and example TikToks. Use add_tiktok / create_format to contribute. list_channels and list_posts cover the Automatiser studio.",
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
      tools: MCP_TOOLS.map((tool) => ({
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
      const result = await callTool(name, args as Record<string, unknown>, actor);
      return rpc(id, toolText(result));
    } catch (error: any) {
      return rpc(id, {
        content: [{ type: "text", text: JSON.stringify({ error: error?.message || "error" }) }],
        isError: true,
      });
    }
  }

  return rpcError(id, -32601, `Method not found: ${method}`);
}

export const affiliateMcp = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (req, res) => {
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
          tools: MCP_TOOLS.map((tool) => tool.name),
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
          if (reply) replies.push(reply);
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
    } catch (error: any) {
      const message = error?.message || "error";
      const status = message === "UNAUTHORIZED" ? 401 : 500;
      res.status(status).json({ error: message });
    }
  }
);
