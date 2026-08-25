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

/** Extrait un code depuis une URL join/ref ou retourne la valeur normalisée. */
export function parseAcquisitionCodeFromInput(raw) {
  const trimmed = String(raw || "").trim();
  if (!trimmed) return "";

  const looksLikeUrl =
    /^https?:\/\//i.test(trimmed) ||
    /^(join\.)?useprocess\.xyz\//i.test(trimmed) ||
    trimmed.includes("useprocess.xyz/");

  if (looksLikeUrl) {
    try {
      const href = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed.replace(/^\/+/, "")}`;
      const url = new URL(href);
      const host = url.hostname.toLowerCase();
      const path = url.pathname.replace(/\/$/, "");

      if (host === "join.useprocess.xyz" && path) {
        const segment = decodeURIComponent(path.replace(/^\//, ""));
        if (segment && !["get", "telecharger", "join", "c"].includes(segment.toLowerCase())) {
          return normalizeAcquisitionCode(segment);
        }
      }

      const joinMatch = path.match(/^\/join\/([^/]+)$/i);
      if (joinMatch?.[1]) {
        return normalizeAcquisitionCode(decodeURIComponent(joinMatch[1]));
      }

      const ref = url.searchParams.get("ref") || url.searchParams.get("code");
      if (ref) return normalizeAcquisitionCode(ref);
    } catch {
      /* fall through */
    }

    const pathMatch = trimmed.match(/(?:join\/|join\.useprocess\.xyz\/)([A-Za-z0-9-]+)/i);
    if (pathMatch?.[1]) {
      return normalizeAcquisitionCode(pathMatch[1]);
    }
  }

  return normalizeAcquisitionCode(trimmed);
}

export async function resolveAcquisitionCode(rawCode) {
  const code = parseAcquisitionCodeFromInput(rawCode);
  if (!code) return null;

  try {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 2500);
    try {
      const response = await fetch(`${FUNCTIONS_BASE}/affiliateResolveCode`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ code }),
        signal: controller.signal,
      });
      if (!response.ok) return null;
      const data = await response.json();
      if (!data?.ok || !data?.type) return null;
      return data;
    } finally {
      window.clearTimeout(timer);
    }
  } catch {
    return null;
  }
}

function affiliateVisitorId() {
  const key = "process.affiliate.visitor";
  try {
    const existing = window.sessionStorage.getItem(key);
    if (existing && existing.length >= 8) return existing;
    const id =
      window.crypto?.randomUUID?.()?.replace(/-/g, "") ||
      `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 12)}`;
    const token = String(id).replace(/[^A-Za-z0-9]/g, "").slice(0, 32);
    window.sessionStorage.setItem(key, token);
    return token;
  } catch {
    return `${Date.now().toString(36)}anon`;
  }
}

export function trackAffiliateLinkEvent(code, event = "view") {
  const normalized = normalizeAcquisitionCode(code);
  if (!normalized) return;

  const visitorId = affiliateVisitorId();
  if (!visitorId) return;

  const payload = JSON.stringify({
    code: normalized,
    event: event === "store" ? "store" : "view",
    visitorId,
  });

  try {
    void fetch(`${FUNCTIONS_BASE}/affiliateTrackLink`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: payload,
      keepalive: true,
    });
  } catch {
    /* tracking must never block the landing page */
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
