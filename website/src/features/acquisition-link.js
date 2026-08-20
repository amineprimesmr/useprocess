import { normalizeReferralCode } from "./referral-link.js";

const FUNCTIONS_BASE =
  import.meta.env.VITE_FUNCTIONS_BASE_URL ||
  "https://us-central1-useprocess-d4385.cloudfunctions.net";

export function normalizeAcquisitionCode(raw) {
  return String(raw || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "")
    .replace(/[^A-Z0-9-]/g, "")
    .slice(0, 24);
}

export async function resolveAcquisitionCode(rawCode) {
  const code = normalizeAcquisitionCode(rawCode || normalizeReferralCode(rawCode));
  if (!code) return null;

  try {
    const response = await fetch(`${FUNCTIONS_BASE}/affiliateResolveCode`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ code }),
    });
    if (!response.ok) return null;
    const data = await response.json();
    if (!data?.ok || !data?.type) return null;
    return data;
  } catch {
    return null;
  }
}

export function buildCreatorLandingUrl(code, utm = {}) {
  const normalized = normalizeAcquisitionCode(code);
  if (!normalized) return "https://useprocess.xyz/app";
  const url = new URL(`https://useprocess.xyz/join/${encodeURIComponent(normalized)}`);
  for (const [key, value] of Object.entries(utm || {})) {
    if (String(value || "").trim()) url.searchParams.set(key, String(value).trim());
  }
  return url.toString();
}

export function buildCreatorShareText(code, displayName = "") {
  const normalized = normalizeAcquisitionCode(code);
  if (!normalized) return "";
  const url = buildCreatorLandingUrl(normalized);
  const label = displayName ? `${displayName} (${normalized})` : normalized;
  return `Download Process with my creator link:\n${url}\n\nCreator code: ${label}`;
}
