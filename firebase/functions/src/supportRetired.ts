import { onRequest } from "firebase-functions/v2/https";
import { setCors } from "./referralShared";

// Older app versions used this endpoint. No messages or personal data are stored.
export const supportSendMessage = onRequest({ region: "us-central1", maxInstances: 2, secrets: [] }, (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  res.status(410).json({ error: "support_chat_retired", email: "contact@processdebloat.com" });
});
