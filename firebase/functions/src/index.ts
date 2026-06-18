import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import Anthropic from "@anthropic-ai/sdk";

admin.initializeApp();

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

type CoachTask =
  | "chat"
  | "dailyBrief"
  | "readinessAnalysis"
  | "bodyScanVision"
  | "faceScanVision"
  | "bodyScanReport"
  | "programSummary"
  | "tool";

interface CoachCompleteBody {
  task: CoachTask;
  model: string;
  system: string;
  userText: string;
  history?: Array<{ role: "user" | "assistant"; text: string }>;
  imageBase64?: string;
  maxTokens?: number;
}

interface CoachStreamBody extends CoachCompleteBody {
  stream?: boolean;
}

function setCors(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

async function verifyFirebaseUser(req: any): Promise<string> {
  const header = req.headers.authorization as string | undefined;
  if (!header?.startsWith("Bearer ")) {
    throw new Error("UNAUTHORIZED");
  }
  const token = header.slice("Bearer ".length);
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded.uid;
}

function normalizeModel(model: string): string {
  switch (model) {
    case "claude-sonnet-4-20250514":
    case "claude-3-7-sonnet-20250219":
    case "claude-3-5-sonnet-20240620":
    case "claude-3-5-sonnet-20241022":
    case "claude-sonnet-4-5-20250929":
      return "claude-sonnet-4-6";
    case "claude-opus-4-20250514":
    case "claude-opus-4-1-20250805":
    case "claude-opus-4-6":
    case "claude-opus-4-7":
    case "claude-opus-4-5-20251101":
      return "claude-opus-4-8";
    case "claude-3-5-haiku-20241022":
    case "claude-3-haiku-20240307":
      return "claude-haiku-4-5-20251001";
    default:
      return model;
  }
}

function buildMessages(body: CoachCompleteBody): Anthropic.MessageParam[] {
  const history = (body.history ?? []).map((m) => ({
    role: m.role,
    content: [{ type: "text" as const, text: m.text }],
  }));

  const last = body.history?.[body.history.length - 1];
  if (last?.role === "user" && last.text === body.userText) {
    return history;
  }

  let userContent: Anthropic.ContentBlockParam[];

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
  } else {
    userContent = [{ type: "text", text: body.userText }];
  }

  return [
    ...history,
    { role: "user", content: userContent },
  ];
}

function maxTokensForTask(task: CoachTask, requested?: number): number {
  if (requested && requested > 0) return Math.min(requested, 4096);
  switch (task) {
    case "dailyBrief":
    case "readinessAnalysis":
      return 400;
    case "bodyScanVision":
    case "faceScanVision":
      return 450;
    case "programSummary":
      return 800;
    case "bodyScanReport":
      return 1600;
    default:
      return 1200;
  }
}

async function sleep(ms: number) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryableAnthropicError(error: unknown): boolean {
  const message = (error as { message?: string })?.message?.toLowerCase() ?? "";
  const status = (error as { status?: number })?.status;
  return (
    status === 529 ||
    status === 503 ||
    status === 429 ||
    message.includes("overloaded") ||
    message.includes("rate limit")
  );
}

async function withAnthropicRetry<T>(
  operation: () => Promise<T>,
  maxAttempts = 3
): Promise<T> {
  let lastError: unknown;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      if (!isRetryableAnthropicError(error) || attempt >= maxAttempts - 1) {
        throw error;
      }
      await sleep(900 * (attempt + 1));
    }
  }
  throw lastError;
}

async function deleteFirestoreCollection(
  col: admin.firestore.CollectionReference,
  batchSize = 100
): Promise<void> {
  const snapshot = await col.limit(batchSize).get();
  if (snapshot.empty) {
    return;
  }

  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  if (snapshot.size >= batchSize) {
    await deleteFirestoreCollection(col, batchSize);
  }
}

async function deleteAllUserFirestoreData(uid: string): Promise<void> {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);

  const directSubcollections = [
    "faceScans",
    "scans",
    "healthDaily",
    "healthBaselines",
    "welcomePlan",
    "coachMeta",
  ];

  for (const name of directSubcollections) {
    await deleteFirestoreCollection(userRef.collection(name));
  }

  const coachThreads = await userRef.collection("coachThreads").get();
  for (const thread of coachThreads.docs) {
    await deleteFirestoreCollection(thread.ref.collection("messages"));
    await thread.ref.delete();
  }

  await userRef.delete();
}

export const deleteUserAccount = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (req, res) => {
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

      try {
        await admin.auth().deleteUser(uid);
      } catch (authError: any) {
        if (authError?.code !== "auth/user-not-found") {
          throw authError;
        }
      }

      try {
        await deleteAllUserFirestoreData(uid);
      } catch (firestoreError) {
        console.warn("[deleteUserAccount] Firestore cleanup failed", uid, firestoreError);
      }

      console.info("[deleteUserAccount] Deleted user", uid);
      res.status(200).json({ ok: true, uid });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      const status = message === "UNAUTHORIZED" ? 401 : 500;
      console.error("[deleteUserAccount]", message);
      res.status(status).json({ error: message });
    }
  }
);

export const coachComplete = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [anthropicApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (req, res) => {
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
      const body = req.body as CoachCompleteBody;

      if (!body?.system || !body?.userText || !body?.model) {
        res.status(400).json({ error: "Missing system, userText or model" });
        return;
      }

      const client = new Anthropic({ apiKey: anthropicApiKey.value() });
      const model = normalizeModel(body.model);
      const response = await withAnthropicRetry(() =>
        client.messages.create({
          model,
          max_tokens: maxTokensForTask(body.task ?? "chat", body.maxTokens),
          system: body.system,
          messages: buildMessages(body),
        })
      );

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
        .set(
          {
            lastTask: body.task ?? "chat",
            lastModel: model,
            lastCalledAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      res.status(200).json({ text, model, uid });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      const status = message === "UNAUTHORIZED" ? 401 : 500;
      console.error("[coachComplete]", message);
      res.status(status).json({ error: message });
    }
  }
);

export const coachStream = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [anthropicApiKey],
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (req, res) => {
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
      const body = req.body as CoachStreamBody;

      if (!body?.system || !body?.userText || !body?.model) {
        res.status(400).json({ error: "Missing system, userText or model" });
        return;
      }

      res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache, no-transform");
      res.setHeader("Connection", "keep-alive");

      const client = new Anthropic({ apiKey: anthropicApiKey.value() });
      const model = normalizeModel(body.model);
      const streamParams = {
        model,
        max_tokens: maxTokensForTask(body.task ?? "chat", body.maxTokens),
        system: body.system,
        messages: buildMessages(body),
      };

      let lastStreamError: unknown;
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          const stream = client.messages.stream(streamParams);

          for await (const event of stream) {
            if (
              event.type === "content_block_delta" &&
              event.delta.type === "text_delta"
            ) {
              if (!res.headersSent) {
                res.flushHeaders?.();
              }
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

          if (!res.headersSent) {
            res.flushHeaders?.();
          }

          res.write(
            `data: ${JSON.stringify({ type: "done", text: finalText, model, uid })}\n\n`
          );
          res.end();

          await admin
            .firestore()
            .collection("users")
            .doc(uid)
            .collection("coachMeta")
            .doc("usage")
            .set(
              {
                lastTask: "chat_stream",
                lastModel: model,
                lastStreamAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          return;
        } catch (error) {
          lastStreamError = error;
          const canRetry =
            !res.headersSent &&
            isRetryableAnthropicError(error) &&
            attempt < 2;
          if (!canRetry) {
            throw error;
          }
          await sleep(900 * (attempt + 1));
        }
      }

      throw lastStreamError;
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[coachStream]", message);
      if (!res.headersSent) {
        res.status(message === "UNAUTHORIZED" ? 401 : 500).json({ error: message });
      } else {
        res.write(`data: ${JSON.stringify({ type: "error", error: message })}\n\n`);
        res.end();
      }
    }
  }
);
