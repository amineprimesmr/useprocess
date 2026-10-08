import { onRequest } from "firebase-functions/v2/https";
import { resolveReferrerUserId, normalizeReferralCode, setCors } from "./referralShared";

// No account, payout or commission records are deleted by retiring the service.
const retired = onRequest({ invoker: "public", cors: true }, (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  res.status(410).json({ error: "CLIPPER_PROGRAM_RETIRED" });
});
// Acknowledge old webhook deliveries without creating further commissions.
export const affiliateRevenueCatWebhook = onRequest({ invoker: "public" }, (_req, res) => {
  res.status(200).json({ ok: true, skipped: "CLIPPER_PROGRAM_RETIRED" });
});
// Kept for released clients that use this URL to validate friend-referral codes.
export const affiliateResolveCode = onRequest({ invoker: "public", cors: true }, async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ error: "METHOD_NOT_ALLOWED" }); return; }
  try {
    const raw = String(req.body?.code ?? "").trim().toUpperCase();
    if (!/^[A-Z0-9]{5}$/.test(raw)) { res.status(404).json({ error: "CODE_NOT_FOUND" }); return; }
    const code = normalizeReferralCode(raw);
    const uid = await resolveReferrerUserId(code);
    if (!uid) { res.status(404).json({ error: "CODE_NOT_FOUND" }); return; }
    res.status(200).json({ ok: true, type: "referral", code });
  } catch {
    res.status(500).json({ error: "RESOLVE_FAILED" });
  }
});
export const affiliatePreparePasswordless = retired;
export const affiliateSendLoginEmail = retired;
export const affiliatePortalHandoff = retired;
export const affiliatePortalHandoffRedeem = retired;
export const affiliateSetLoginEmail = retired;
export const affiliateTrackLink = retired;
export const affiliateTrackFunnel = retired;
export const affiliateRegister = retired;
export const affiliateApply = retired;
export const affiliateSyncProfile = retired;
export const affiliateDashboard = retired;
export const affiliateAdminCreate = retired;
export const affiliateAdminProvisionAuth = retired;
export const affiliateAdminApprove = retired;
export const affiliateAdminListPending = retired;
export const affiliateAdminMarkPaid = retired;
export const affiliateReleaseHeldCommissions = retired;
export const affiliateTikTokStudio = retired;
export const affiliateTikTokOAuthCallback = retired;
export const affiliateLeaderboard = retired;
export const affiliateLibrary = retired;
export const affiliateMcp = retired;
