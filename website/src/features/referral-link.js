import { getIosAppStoreUrl } from "./app-store-urls.js";
import { appCopy } from "./app-copy.js";

const REFERRAL_STORAGE_KEY = "process_referral_code";
const REFERRAL_STORAGE_TS_KEY = "process_referral_code_at";
const REFERRAL_TTL_MS = 1000 * 60 * 60 * 24 * 30; // 30 jours

export function normalizeReferralCode(raw) {
  return String(raw || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "")
    .replace(/[^A-Z0-9-]/g, "");
}

export function parseReferralCodeFromLocation(location = window.location) {
  const path = String(location.pathname || "").replace(/\/$/, "");
  const host = String(location.hostname || "").toLowerCase();

  if (host === "join.useprocess.xyz" && path) {
    const rootCode = path.replace(/^\//, "");
    if (rootCode && !["get", "telecharger", "join"].includes(rootCode.toLowerCase())) {
      return normalizeReferralCode(decodeURIComponent(rootCode));
    }
  }

  const joinMatch = path.match(/^\/join\/([^/]+)$/i);
  if (joinMatch?.[1]) {
    return normalizeReferralCode(decodeURIComponent(joinMatch[1]));
  }

  const params = new URLSearchParams(location.search || "");
  const ref = params.get("ref") || params.get("code");
  if (ref) return normalizeReferralCode(ref);

  return readRememberedReferralCode();
}

export function buildReferralLandingUrl(code) {
  const normalized = normalizeReferralCode(code);
  if (!normalized) return "https://useprocess.xyz/?get=1";
  return `https://useprocess.xyz/join/${encodeURIComponent(normalized)}`;
}

export function buildReferralShareText(code) {
  const normalized = normalizeReferralCode(code);
  if (!normalized) return "";
  const url = buildReferralLandingUrl(normalized);
  return appCopy(
    `Télécharge Process gratuitement avec mon lien :\n${url}\n\nMon code parrainage : ${normalized}`,
    `Download Process for free with my link:\n${url}\n\nMy referral code: ${normalized}`
  );
}

export function buildReferralDeepLink(code) {
  const normalized = normalizeReferralCode(code);
  return `process://referral?code=${encodeURIComponent(normalized)}`;
}

export function buildAppStoreUrlWithReferral(code) {
  const base = getIosAppStoreUrl();
  const normalized = normalizeReferralCode(code);
  if (!normalized) return base;
  const separator = base.includes("?") ? "&" : "?";
  return `${base}${separator}ct=ref_${encodeURIComponent(normalized)}`;
}

export function rememberReferralCode(code) {
  const normalized = normalizeReferralCode(code);
  if (!normalized) return;
  try {
    localStorage.setItem(REFERRAL_STORAGE_KEY, normalized);
    localStorage.setItem(REFERRAL_STORAGE_TS_KEY, String(Date.now()));
  } catch {
    // ignore quota / private mode
  }
}

export function readRememberedReferralCode() {
  try {
    const code = normalizeReferralCode(localStorage.getItem(REFERRAL_STORAGE_KEY) || "");
    if (!code) return "";
    const savedAt = Number(localStorage.getItem(REFERRAL_STORAGE_TS_KEY) || "0");
    if (savedAt > 0 && Date.now() - savedAt > REFERRAL_TTL_MS) {
      localStorage.removeItem(REFERRAL_STORAGE_KEY);
      localStorage.removeItem(REFERRAL_STORAGE_TS_KEY);
      return "";
    }
    return code;
  } catch {
    return "";
  }
}

export async function copyReferralInvite(code) {
  const text = buildReferralShareText(code);
  if (!text) return false;
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // fallback below
  }

  try {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    const ok = document.execCommand("copy");
    textarea.remove();
    return ok;
  } catch {
    return false;
  }
}
