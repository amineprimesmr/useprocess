import { onRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { SignedDataVerifier, Environment, ResponseBodyV2DecodedPayload } from "@apple/app-store-server-library";
import { db } from "./billingAdmin";
import { APPLE_ROOT_CERTIFICATES } from "./appleRootCertificates";

const verifiers = [Environment.PRODUCTION, Environment.SANDBOX].map(environment =>
  new SignedDataVerifier(APPLE_ROOT_CERTIFICATES, true, environment, "com.useprocess", 6753808143));

export async function verifyAppleBillingNotification(signedPayload: unknown) {
  if (typeof signedPayload !== "string" || signedPayload.length > 250000) throw Error("Invalid notification");
  for (const verifier of verifiers) {
    try { return await verifier.verifyAndDecodeNotification(signedPayload); } catch { /* Try the other verified environment. */ }
  }
  throw Error("Invalid Apple signature, certificate chain, app or environment");
}

export async function storeAppleBillingNotification(payload: ResponseBodyV2DecodedPayload) {
  if (!payload.notificationUUID || !/^[a-zA-Z0-9-]{16,128}$/.test(payload.notificationUUID)) throw Error("Missing notification identity");
  const event = db.doc(`appleBillingNotifications/${payload.notificationUUID}`);
  await db.runTransaction(async tx => {
    const existing = await tx.get(event);
    if (existing.exists) return;
    tx.set(event, { payload, status: "received", receivedAt: FieldValue.serverTimestamp() });
  });
  return event;
}

/** Receives Apple's signed App Store payload and preserves the existing RevenueCat route.
 * The destination is operator-configured and strictly restricted to RevenueCat. */
export const appleBillingNotifications = onRequest({ timeoutSeconds: 60, maxInstances: 10 }, async (req, res) => {
  if (req.method !== "POST") { res.sendStatus(405); return; }
  let payload: ResponseBodyV2DecodedPayload;
  try { payload = await verifyAppleBillingNotification(req.body?.signedPayload); }
  catch { res.status(401).send("Invalid Apple notification"); return; }
  try {
    const event = await storeAppleBillingNotification(payload);
    const saved = (await event.get()).data();
    if (saved?.status === "forwarded") { res.sendStatus(200); return; }
    if (payload.notificationType === "EXTERNAL_PURCHASE_TOKEN") {
      await event.set({ status: "forwarded", handledBy: "retired_external_billing" }, { merge: true });
      res.sendStatus(200); return;
    }
    const config = (await db.doc("billingConfiguration/apple").get()).data();
    const destination = new URL(config?.revenueCatNotificationURL ?? "");
    if (destination.protocol !== "https:" || destination.hostname !== "api.revenuecat.com" ||
        !destination.pathname.startsWith("/v1/incoming-webhooks/apple-server-to-server-notification/")) throw Error("Forwarding destination not configured");
    const response = await fetch(destination, { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ signedPayload: req.body.signedPayload }), signal: AbortSignal.timeout(15000), redirect: "error" });
    if (!response.ok) throw Error("RevenueCat notification delivery failed");
    await event.set({ status: "forwarded", forwardedAt: FieldValue.serverTimestamp() }, { merge: true });
    res.sendStatus(200);
  } catch {
    console.error("appleBillingNotifications delivery failed");
    res.status(503).send("Retry later");
  }
});
