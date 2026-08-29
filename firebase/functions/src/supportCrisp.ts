import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import {
  db,
  httpStatusForError,
  setCors,
  verifyAppAttestation,
  verifyFirebaseUser,
} from "./referralShared";

/**
 * Inbox opérateur = Crisp. L’app n’ouvre plus le ChatViewController Crisp.
 *
 * Secrets Firebase (à setter une fois) :
 *   firebase functions:secrets:set CRISP_IDENTIFIER
 *   firebase functions:secrets:set CRISP_KEY
 *   firebase functions:secrets:set CRISP_WEBHOOK_SECRET
 *
 * Jeton : Crisp → Paramètres → Paramètres du workspace → Configuration avancée → API Token.
 * Webhook : même écran → Web Hooks, URL
 *   https://us-central1-useprocess-d4385.cloudfunctions.net/supportCrispWebhook?token=CRISP_WEBHOOK_SECRET
 * Events : message:send, message:received
 */

const DEFAULT_WEBSITE_ID = "eabb57a7-e62e-46fa-9778-99601f5b84ac";
const MAX_TEXT_LENGTH = 4000;
const MIN_SEND_INTERVAL_MS = 1200;

const crispIdentifier = defineSecret("CRISP_IDENTIFIER");
const crispKey = defineSecret("CRISP_KEY");
const crispWebhookSecret = defineSecret("CRISP_WEBHOOK_SECRET");

const CRISP_SECRETS = [crispIdentifier, crispKey, crispWebhookSecret];

type SupportFrom = "user" | "operator";

interface ThreadMeta {
  crispSessionId?: string;
  updatedAt?: admin.firestore.Timestamp;
  lastSentAt?: admin.firestore.Timestamp;
  lastFrom?: SupportFrom;
}

function websiteId(): string {
  const fromEnv = String(process.env.CRISP_WEBSITE_ID ?? "").trim();
  if (fromEnv && !fromEnv.startsWith("YOUR_")) return fromEnv;
  return DEFAULT_WEBSITE_ID;
}

function supportMessages(uid: string) {
  return db().collection("users").doc(uid).collection("supportMessages");
}

function threadRef(uid: string) {
  return db().collection("users").doc(uid).collection("supportMeta").doc("thread");
}

function sessionIndexRef(sessionId: string) {
  return db().collection("crispSessions").doc(sessionId);
}

function extractText(content: unknown): string | null {
  if (typeof content === "string") {
    const trimmed = content.trim();
    return trimmed || null;
  }
  if (content && typeof content === "object") {
    const value = content as Record<string, unknown>;
    if (typeof value.text === "string" && value.text.trim()) return value.text.trim();
    if (typeof value.message === "string" && value.message.trim()) return value.message.trim();
    if (typeof value.url === "string" && value.url.trim()) return value.url.trim();
  }
  return null;
}

function webhookTokenFromRequest(req: { query?: Record<string, unknown>; headers: Record<string, unknown> }): string {
  const queryToken = String(req.query?.token ?? "").trim();
  if (queryToken) return queryToken;
  const header = String(req.headers["x-crisp-webhook-token"] ?? "").trim();
  return header;
}

async function crispRequest<T>(
  method: string,
  path: string,
  body?: unknown
): Promise<T> {
  const identifier = crispIdentifier.value();
  const key = crispKey.value();
  if (!identifier || !key) {
    throw new Error("CRISP_UNAVAILABLE");
  }

  const auth = Buffer.from(`${identifier}:${key}`).toString("base64");
  const response = await fetch(`https://api.crisp.chat/v1${path}`, {
    method,
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/json",
      "X-Crisp-Tier": "website",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const json = (await response.json().catch(() => ({}))) as {
    error?: boolean;
    reason?: string;
    data?: T;
  };

  if (!response.ok || json.error) {
    const reason = json.reason || response.statusText || "error";
    console.error("[Crisp]", method, path, response.status, reason);
    throw new Error(`CRISP_${response.status}:${reason}`);
  }

  return json.data as T;
}

async function createCrispSession(): Promise<string> {
  const data = await crispRequest<{ session_id?: string }>(
    "POST",
    `/website/${websiteId()}/conversation`
  );
  const sessionId = String(data?.session_id ?? "").trim();
  if (!sessionId) throw new Error("CRISP_UNAVAILABLE");
  return sessionId;
}

async function patchConversationMeta(
  sessionId: string,
  meta: {
    nickname?: string;
    email?: string;
    language?: string;
    subscription?: string;
    acquisitionSource?: string;
    appVersion?: string;
    userId: string;
  }
): Promise<void> {
  const payload: Record<string, unknown> = {
    nickname: meta.nickname || "Process",
    segments: ["ios_app"],
    data: {
      user_id: meta.userId,
      app_language: meta.language || "",
      subscription: meta.subscription || "",
      acquisition_source: meta.acquisitionSource || "",
      app_version: meta.appVersion || "",
    },
  };
  if (meta.email && meta.email.includes("@")) {
    payload.email = meta.email;
  }

  try {
    await crispRequest(
      "PATCH",
      `/website/${websiteId()}/conversation/${sessionId}/meta`,
      payload
    );
  } catch (error) {
    console.warn("[Crisp] meta patch failed", error);
  }
}

async function sendCrispUserMessage(sessionId: string, text: string): Promise<number | null> {
  return sendCrispMessage(sessionId, "user", "text", text);
}

async function sendCrispMessage(
  sessionId: string,
  from: "user" | "operator",
  type: "text" | "note",
  text: string
): Promise<number | null> {
  const data = await crispRequest<{ fingerprint?: number }>(
    "POST",
    `/website/${websiteId()}/conversation/${sessionId}/message`,
    {
      type,
      from,
      origin: "chat",
      content: text,
    }
  );
  return typeof data?.fingerprint === "number" ? data.fingerprint : null;
}

async function reopenConversation(sessionId: string): Promise<void> {
  try {
    await crispRequest(
      "PATCH",
      `/website/${websiteId()}/conversation/${sessionId}/state`,
      { state: "unresolved" }
    );
  } catch {
    // Conversation already open, or plugin cannot change state.
  }
}

function isMissingSessionError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return (
    message.includes("CRISP_404") ||
    message.toLowerCase().includes("not_found") ||
    message.toLowerCase().includes("session")
  );
}

async function resolveSessionId(uid: string): Promise<{ sessionId: string; created: boolean }> {
  const snap = await threadRef(uid).get();
  const existing = String((snap.data() as ThreadMeta | undefined)?.crispSessionId ?? "").trim();
  if (existing) {
    return { sessionId: existing, created: false };
  }

  const sessionId = await createCrispSession();
  await sessionIndexRef(sessionId).set({
    userId: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { sessionId, created: true };
}

export const supportSendMessage = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: CRISP_SECRETS,
    timeoutSeconds: 60,
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

      const text = String(req.body?.text ?? "").trim();
      if (!text || text.length > MAX_TEXT_LENGTH) {
        throw new Error("INVALID_TEXT");
      }

      const clientMessageId = String(req.body?.messageId ?? "").trim();
      const messageId =
        /^[A-Za-z0-9_-]{8,64}$/.test(clientMessageId)
          ? clientMessageId
          : db().collection("_").doc().id;

      const threadSnap = await threadRef(uid).get();
      const lastSentAt = (threadSnap.data() as ThreadMeta | undefined)?.lastSentAt;
      if (lastSentAt?.toMillis && Date.now() - lastSentAt.toMillis() < MIN_SEND_INTERVAL_MS) {
        throw new Error("RATE_LIMITED");
      }

      let { sessionId } = await resolveSessionId(uid);

      const authUser = await admin.auth().getUser(uid).catch(() => null);
      const nickname = String(req.body?.nickname ?? authUser?.displayName ?? "").trim();
      const email = String(req.body?.email ?? authUser?.email ?? "").trim();

      await patchConversationMeta(sessionId, {
        userId: uid,
        nickname,
        email,
        language: String(req.body?.language ?? "").trim(),
        subscription: String(req.body?.subscription ?? "").trim(),
        acquisitionSource: String(req.body?.acquisitionSource ?? "").trim(),
        appVersion: String(req.body?.appVersion ?? "").trim(),
      });

      let fingerprint: number | null = null;
      try {
        await reopenConversation(sessionId);
        fingerprint = await sendCrispUserMessage(sessionId, text);
      } catch (error) {
        if (!isMissingSessionError(error)) throw error;
        sessionId = await createCrispSession();
        await sessionIndexRef(sessionId).set({
          userId: uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await patchConversationMeta(sessionId, {
          userId: uid,
          nickname,
          email,
          language: String(req.body?.language ?? "").trim(),
          subscription: String(req.body?.subscription ?? "").trim(),
          acquisitionSource: String(req.body?.acquisitionSource ?? "").trim(),
          appVersion: String(req.body?.appVersion ?? "").trim(),
        });
        fingerprint = await sendCrispUserMessage(sessionId, text);
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      await supportMessages(uid).doc(messageId).set({
        text,
        from: "user",
        createdAt: now,
        origin: "app",
        crispFingerprint: fingerprint,
      });
      await threadRef(uid).set(
        {
          crispSessionId: sessionId,
          updatedAt: now,
          lastSentAt: now,
          lastFrom: "user",
        },
        { merge: true }
      );

      res.status(200).json({ ok: true, messageId, sessionId });
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "Unknown error";
      console.error("[supportSendMessage]", message);
      const status = message.startsWith("CRISP_")
        ? 503
        : httpStatusForError(message);
      res.status(status).json({ error: message.startsWith("CRISP_") ? "CRISP_UNAVAILABLE" : message });
    }
  }
);

async function persistOperatorMessage(params: {
  sessionId: string;
  text: string;
  fingerprint: number | null;
  timestampMs: number | null;
  userId?: string;
  origin?: string;
}): Promise<boolean> {
  let userId = String(params.userId ?? "").trim();
  if (!userId) {
    const index = await sessionIndexRef(params.sessionId).get();
    userId = String(index.data()?.userId ?? "").trim();
  }
  if (!userId) {
    console.warn("[supportCrisp] unknown session", params.sessionId);
    return false;
  }

  await sessionIndexRef(params.sessionId).set(
    {
      userId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const messageId =
    params.fingerprint != null
      ? `op-${params.fingerprint}`
      : `op-${params.sessionId}-${params.timestampMs || Date.now()}`;

  const doc = supportMessages(userId).doc(messageId);
  const existing = await doc.get();
  if (existing.exists) return false;

  const createdAt = params.timestampMs
    ? admin.firestore.Timestamp.fromMillis(params.timestampMs)
    : admin.firestore.FieldValue.serverTimestamp();

  await doc.set({
    text: params.text,
    from: "operator",
    createdAt,
    origin: params.origin || "crisp",
    crispFingerprint: params.fingerprint,
    crispSessionId: params.sessionId,
  });
  await threadRef(userId).set(
    {
      crispSessionId: params.sessionId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastFrom: "operator",
    },
    { merge: true }
  );
  return true;
}

interface CrispConversation {
  session_id?: string;
  updated_at?: number;
  unread?: { visitor?: number; operator?: number };
  meta?: { data?: Record<string, unknown> };
}

interface CrispMessage {
  from?: string;
  type?: string;
  content?: unknown;
  fingerprint?: number;
  timestamp?: number;
  session_id?: string;
}

async function ingestOperatorMessagesForSession(
  sessionId: string,
  userId: string
): Promise<number> {
  const messages = await crispRequest<CrispMessage[]>(
    "GET",
    `/website/${websiteId()}/conversation/${sessionId}/messages`
  );
  let stored = 0;
  for (const message of Array.isArray(messages) ? messages : []) {
    if (String(message.from ?? "") !== "operator") continue;
    const type = String(message.type ?? "text");
    if (type === "note" || type === "event") continue;
    const text = extractText(message.content);
    if (!text) continue;
    const created = await persistOperatorMessage({
      sessionId,
      text,
      fingerprint: typeof message.fingerprint === "number" ? message.fingerprint : null,
      timestampMs: typeof message.timestamp === "number" ? message.timestamp : null,
      userId,
    });
    if (created) stored += 1;
  }
  return stored;
}

export const supportCrispPoll = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Europe/Paris",
    secrets: CRISP_SECRETS,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async () => {
    const listed = await crispRequest<CrispConversation[]>(
      "GET",
      `/website/${websiteId()}/conversations/1`
    );
    const conversations = Array.isArray(listed) ? listed : [];
    const now = Date.now();
    let fetched = 0;

    for (const conv of conversations) {
      const sessionId = String(conv.session_id ?? "").trim();
      if (!sessionId) continue;

      const metaUserId = String(conv.meta?.data?.user_id ?? "").trim();
      const index = await sessionIndexRef(sessionId).get();
      const userId = metaUserId || String(index.data()?.userId ?? "").trim();
      if (!userId) continue;

      const unreadVisitor = Number(conv.unread?.visitor ?? 0);
      const recentlyUpdated =
        typeof conv.updated_at === "number" && now - conv.updated_at < 15 * 60 * 1000;
      if (unreadVisitor <= 0 && !recentlyUpdated) continue;
      if (fetched >= 6) break;
      fetched += 1;

      try {
        await ingestOperatorMessagesForSession(sessionId, userId);
      } catch (error) {
        console.warn("[supportCrispPoll] session failed", sessionId, error);
      }
    }
  }
);

function readWebhookEvents(body: unknown): Array<Record<string, unknown>> {
  if (!body || typeof body !== "object") return [];
  const payload = body as Record<string, unknown>;
  if (Array.isArray(payload.events)) {
    return payload.events.filter((item) => item && typeof item === "object") as Array<
      Record<string, unknown>
    >;
  }
  if (typeof payload.event === "string") {
    return [payload];
  }
  if (payload.session_id && payload.from) {
    return [{ event: "message:send", data: payload }];
  }
  return [];
}

function eventData(event: Record<string, unknown>): Record<string, unknown> {
  if (event.data && typeof event.data === "object") {
    return event.data as Record<string, unknown>;
  }
  return event;
}

export const supportCrispWebhook = onRequest(
  {
    invoker: "public",
    cors: false,
    secrets: CRISP_SECRETS,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    if (req.method === "GET") {
      res.status(200).json({ ok: true });
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const expected = crispWebhookSecret.value();
      const provided = webhookTokenFromRequest(req);
      if (!expected || provided !== expected) {
        res.status(401).json({ error: "UNAUTHORIZED" });
        return;
      }

      const events = readWebhookEvents(req.body);
      for (const event of events) {
        const name = String(event.event ?? "").trim();
        if (name && name !== "message:send" && name !== "message:received") {
          continue;
        }

        const data = eventData(event);
        const from = String(data.from ?? "").trim();
        if (from !== "operator") continue;

        const type = String(data.type ?? "text").trim();
        if (type === "note" || type === "event") continue;

        const text = extractText(data.content);
        if (!text) continue;

        const sessionId = String(data.session_id ?? "").trim();
        if (!sessionId) continue;

        const eventWebsiteId = String(data.website_id ?? event.website_id ?? "").trim();
        if (eventWebsiteId && eventWebsiteId !== websiteId()) continue;

        const fingerprint =
          typeof data.fingerprint === "number" ? data.fingerprint : null;
        const timestampMs =
          typeof data.timestamp === "number" ? data.timestamp : null;

        await persistOperatorMessage({
          sessionId,
          text,
          fingerprint,
          timestampMs,
        });
      }

      res.status(200).json({ ok: true });
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "Unknown error";
      console.error("[supportCrispWebhook]", message);
      res.status(500).json({ error: "WEBHOOK_FAILED" });
    }
  }
);
