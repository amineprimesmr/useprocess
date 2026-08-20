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
import { verifyPremiumSubscriber } from "./premiumAccess";
import { isValidReferralCode, normalizeReferralCode } from "./referralShared";
import {
  registerAppleAuthorizationCode,
  resolveAppleSignInConfig,
  revokeAppleSignInForUser,
  type AppleSignInSecrets,
} from "./appleSignIn";

admin.initializeApp();

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");
const revenueCatSecretKey = defineSecret("REVENUECAT_SECRET_API_KEY");
const appleSignInTeamId = defineSecret("APPLE_SIGNIN_TEAM_ID");
const appleSignInKeyId = defineSecret("APPLE_SIGNIN_KEY_ID");
const appleSignInPrivateKey = defineSecret("APPLE_SIGNIN_PRIVATE_KEY");

const APPLE_SIGNIN_SECRETS = [
  appleSignInTeamId,
  appleSignInKeyId,
  appleSignInPrivateKey,
];

function appleSignInConfigFromSecrets(): ReturnType<typeof resolveAppleSignInConfig> {
  const secrets: AppleSignInSecrets = {
    teamId: appleSignInTeamId.value(),
    keyId: appleSignInKeyId.value(),
    privateKey: appleSignInPrivateKey.value(),
    clientId: process.env.APPLE_SIGNIN_CLIENT_ID || "com.useprocess",
  };
  return resolveAppleSignInConfig(secrets);
}

function isAppleSignInProvider(user: admin.auth.UserRecord): boolean {
  return user.providerData.some((provider) => provider.providerId === "apple.com");
}
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

async function deleteReferralArtifactsForUser(uid: string): Promise<void> {
  const db = admin.firestore();
  const program = await db
    .collection("users")
    .doc(uid)
    .collection("referralMeta")
    .doc("program")
    .get();

  const rawCode = program.data()?.referralCode;
  if (typeof rawCode === "string" && rawCode.trim()) {
    const normalized = normalizeReferralCode(rawCode);
    if (!isValidReferralCode(normalized)) return;
    const codeRef = db.collection("referralCodes").doc(normalized);
    const codeSnap = await codeRef.get();
    if (codeSnap.exists && codeSnap.data()?.userId === uid) {
      await codeRef.delete();
    }
  }
}

async function deleteAllUserFirestoreData(uid: string): Promise<void> {
  const db = admin.firestore();
  await deleteReferralArtifactsForUser(uid);
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
    secrets: APPLE_SIGNIN_SECRETS,
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

      const body = (req.body ?? {}) as { appleAuthorizationCode?: string };
      const appleAuthorizationCode =
        typeof body.appleAuthorizationCode === "string"
          ? body.appleAuthorizationCode.trim()
          : undefined;

      let appleRevoked: boolean | undefined;
      let appleRevokeReason: string | undefined;

      try {
        const authUser = await admin.auth().getUser(uid);
        if (isAppleSignInProvider(authUser)) {
          try {
            const appleConfig = appleSignInConfigFromSecrets();
            const revokeResult = await revokeAppleSignInForUser(
              uid,
              appleConfig,
              appleAuthorizationCode
            );
            appleRevoked = revokeResult.revoked;
            appleRevokeReason = revokeResult.reason;
          } catch (appleError: any) {
            console.warn(
              "[deleteUserAccount] Apple revoke skipped",
              appleError?.message ?? appleError
            );
            appleRevoked = false;
            appleRevokeReason = appleError?.message ?? "APPLE_CONFIG_UNAVAILABLE";
          }
        }
      } catch (authLookupError: any) {
        console.warn(
          "[deleteUserAccount] auth lookup before Apple revoke",
          authLookupError?.message ?? authLookupError
        );
      }

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

      console.info("[deleteUserAccount] Deleted user and data", uid, {
        appleRevoked,
        appleRevokeReason,
      });
      res.status(200).json({ ok: true, uid, appleRevoked, appleRevokeReason });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      const status = message === "UNAUTHORIZED" ? 401 : 500;
      console.error("[deleteUserAccount]", message);
      res.status(status).json({ error: message });
    }
  }
);

export const appleSignInRegisterToken = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: APPLE_SIGNIN_SECRETS,
    timeoutSeconds: 60,
    memory: "256MiB",
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

      const body = (req.body ?? {}) as {
        authorizationCode?: string;
        appleUserId?: string;
      };
      const authorizationCode =
        typeof body.authorizationCode === "string"
          ? body.authorizationCode.trim()
          : "";
      if (!authorizationCode) {
        res.status(400).json({ error: "Missing authorizationCode" });
        return;
      }

      const appleUserId =
        typeof body.appleUserId === "string" ? body.appleUserId.trim() : undefined;

      const appleConfig = appleSignInConfigFromSecrets();
      await registerAppleAuthorizationCode(
        uid,
        authorizationCode,
        appleConfig,
        appleUserId
      );

      res.status(200).json({ ok: true, uid });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      const status =
        message === "UNAUTHORIZED"
          ? 401
          : message.startsWith("APPLE_") || message === "APPLE_SIGNIN_CONFIG_INCOMPLETE"
            ? 503
            : 500;
      console.error("[appleSignInRegisterToken]", message);
      res.status(status).json({ error: message });
    }
  }
);

export const coachComplete = onRequest(
  {
    invoker: "public",
    cors: true,
    secrets: [anthropicApiKey, revenueCatSecretKey],
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
      await verifyPremiumSubscriber(uid, revenueCatSecretKey.value());
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
    secrets: [anthropicApiKey, revenueCatSecretKey],
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
      await verifyPremiumSubscriber(uid, revenueCatSecretKey.value());
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

export { referralSyncProgram, referralRegister, referralDashboard } from "./referral";
export {
  referralConfirmSubscription,
  referralRevenueCatWebhook,
} from "./referralRewards";
export {
  affiliateResolveCode,
  affiliateRegister,
  affiliateApply,
  affiliateSyncProfile,
  affiliateDashboard,
  affiliateAdminCreate,
  affiliateAdminProvisionAuth,
  affiliateAdminApprove,
  affiliateAdminListPending,
  affiliateAdminMarkPaid,
} from "./affiliate";
export {
  affiliateRevenueCatWebhook,
  affiliateReleaseHeldCommissions,
} from "./affiliateCommissions";
export {
  affiliateStripeConnectStart,
  affiliateStripeConnectSync,
  affiliateStripeConnectDashboard,
  affiliateStripeWebhook,
} from "./affiliateStripe";
export { supportSendMessage, supportCrispWebhook, supportCrispPoll } from "./supportCrisp";
