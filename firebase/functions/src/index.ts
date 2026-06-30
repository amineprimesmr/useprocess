import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import Anthropic from "@anthropic-ai/sdk";
import {
  httpStatusForError,
  maxTokensForTask,
  normalizeModel,
  validateCoachBody,
  type CoachCompleteBody,
  type CoachStreamBody,
  type CoachTask,
} from "./coachValidation";

admin.initializeApp();

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");
const enforceAppCheck = process.env.ENFORCE_APP_CHECK === "true";

function setCors(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization, X-Firebase-AppCheck"
  );
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

async function verifyAppAttestation(req: any): Promise<void> {
  const token = req.header("X-Firebase-AppCheck") as string | undefined;
  if (!token) {
    if (enforceAppCheck) throw new Error("INVALID_APP_CHECK");
    console.warn("[AppCheck] Missing token (monitoring mode)");
    return;
  }

  try {
    await admin.appCheck().verifyToken(token);
  } catch (error) {
    if (enforceAppCheck) throw new Error("INVALID_APP_CHECK");
    console.warn("[AppCheck] Invalid token (monitoring mode)", error);
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

async function enforceCoachRateLimit(uid: string): Promise<void> {
  const db = admin.firestore();
  const ref = db
    .collection("users")
    .doc(uid)
    .collection("coachMeta")
    .doc("rateLimit");
  const now = Date.now();
  const day = new Date(now).toISOString().slice(0, 10);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    const count = data?.day === day ? Number(data?.count ?? 0) : 0;
    const lastCallAt = data?.lastCallAt?.toMillis?.() ?? 0;

    if (count >= 500 || now - lastCallAt < 750) {
      throw new Error("RATE_LIMITED");
    }

    transaction.set(
      ref,
      {
        day,
        count: count + 1,
        lastCallAt: admin.firestore.Timestamp.fromMillis(now),
      },
      { merge: true }
    );
  });
}

async function deleteAllUserFirestoreData(uid: string): Promise<void> {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);

  // Supprime le document et toutes ses sous-collections, y compris celles
  // qui seront ajoutées plus tard au modèle de données.
  await db.recursiveDelete(userRef);

  const usernames = await db
    .collection("usernames")
    .where("userId", "==", uid)
    .get();
  if (!usernames.empty) {
    const batch = db.batch();
    usernames.docs.forEach((document) => batch.delete(document.ref));
    await batch.commit();
  }
}

export const deleteUserAccount = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 180,
    memory: "1GiB",
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
      await verifyAppAttestation(req);

      // Les données sont effacées avant l'identité : aucune réponse positive
      // n'est envoyée si le nettoyage des données personnelles échoue.
      await deleteAllUserFirestoreData(uid);

      try {
        await admin.auth().deleteUser(uid);
      } catch (authError: any) {
        if (authError?.code !== "auth/user-not-found") {
          throw authError;
        }
      }

      console.info("[deleteUserAccount] Deleted user and data", uid);
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
      await verifyAppAttestation(req);
      const body = req.body as CoachCompleteBody;

      const validationError = validateCoachBody(body);
      if (validationError) {
        res.status(400).json({ error: validationError });
        return;
      }
      await enforceCoachRateLimit(uid);

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
      const status = httpStatusForError(message);
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
      await verifyAppAttestation(req);
      const body = req.body as CoachStreamBody;

      const validationError = validateCoachBody(body);
      if (validationError) {
        res.status(400).json({ error: validationError });
        return;
      }
      await enforceCoachRateLimit(uid);

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
        res.status(httpStatusForError(message)).json({ error: message });
      } else {
        res.write(`data: ${JSON.stringify({ type: "error", error: message })}\n\n`);
        res.end();
      }
    }
  }
);
