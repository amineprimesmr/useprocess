import { getIosAppStoreUrl } from "./app-store-urls.js";
import { getAppBioShortUrl } from "./bio-link.js";
import { appCopy } from "./app-copy.js";

const REFERRAL_STORAGE_KEY = "process_referral_code";
const REFERRAL_STORAGE_TS_KEY = "process_referral_code_at";
const UTM_STORAGE_KEY = "process_acquisition_utm";
const UTM_STORAGE_TS_KEY = "process_acquisition_utm_at";
const REFERRAL_TTL_MS = 1000 * 60 * 60 * 24 * 30; // 30 jours

const UTM_KEYS = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"];

export const REFERRAL_CODE_LENGTH = 5;

export function normalizeReferralCode(raw) {
  return String(raw || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "")
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, REFERRAL_CODE_LENGTH);
}

/** Codes affiliés / join (plus longs que les codes parrainage à 5 caractères). */
export function normalizeAcquisitionCodeFromUrl(raw) {
  return String(raw || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "")
    .replace(/[^A-Z0-9-]/g, "")
    .slice(0, 24);
}

export function isValidReferralCode(raw) {
  return normalizeReferralCode(raw).length === REFERRAL_CODE_LENGTH;
}

export function parseUtmFromLocation(location = window.location) {
  const params = new URLSearchParams(location.search || "");
  const utm = {};
  for (const key of UTM_KEYS) {
    const value = String(params.get(key) || "").trim();
    if (value) utm[key] = value;
  }
  // Alias courts
  const source = String(params.get("source") || "").trim();
  const medium = String(params.get("medium") || "").trim();
  const campaign = String(params.get("campaign") || "").trim();
  if (source && !utm.utm_source) utm.utm_source = source;
  if (medium && !utm.utm_medium) utm.utm_medium = medium;
  if (campaign && !utm.utm_campaign) utm.utm_campaign = campaign;

  // Path /c/tiktok
  const path = String(location.pathname || "").replace(/\/$/, "");
  const campaignPath = path.match(/^\/c\/([^/]+)$/i);
  if (campaignPath?.[1]) {
    const slug = decodeURIComponent(campaignPath[1]).trim().toLowerCase();
    if (slug) {
      if (!utm.utm_source) utm.utm_source = slug;
      if (!utm.utm_medium) utm.utm_medium = "campaign";
      if (!utm.utm_campaign) utm.utm_campaign = slug;
    }
  }

  return utm;
}

export function rememberUtm(utm) {
  if (!utm || typeof utm !== "object") return;
  const cleaned = {};
  for (const key of UTM_KEYS) {
    const value = String(utm[key] || "").trim();
    if (value) cleaned[key] = value;
  }
  if (!Object.keys(cleaned).length) return;
  try {
    localStorage.setItem(UTM_STORAGE_KEY, JSON.stringify(cleaned));
    localStorage.setItem(UTM_STORAGE_TS_KEY, String(Date.now()));
  } catch {
    // ignore
  }
}

export function readRememberedUtm() {
  try {
    const savedAt = Number(localStorage.getItem(UTM_STORAGE_TS_KEY) || "0");
    if (savedAt > 0 && Date.now() - savedAt > REFERRAL_TTL_MS) {
      localStorage.removeItem(UTM_STORAGE_KEY);
      localStorage.removeItem(UTM_STORAGE_TS_KEY);
      return {};
    }
    const raw = localStorage.getItem(UTM_STORAGE_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

export function resolveAcquisitionUtm(location = window.location) {
  const fromUrl = parseUtmFromLocation(location);
  if (Object.keys(fromUrl).length) {
    rememberUtm(fromUrl);
    return fromUrl;
  }
  return readRememberedUtm();
}

function appendParams(baseUrl, params) {
  const entries = Object.entries(params || {}).filter(([, v]) => String(v || "").trim());
  if (!entries.length) return baseUrl;
  const url = new URL(baseUrl, "https://useprocess.xyz");
  for (const [key, value] of entries) {
    url.searchParams.set(key, String(value).trim());
  }
  // Keep absolute App Store / join URLs intact
  if (/^https?:\/\//i.test(baseUrl)) {
    return url.toString();
  }
  return `${url.pathname}${url.search}${url.hash}`;
}

export function parseReferralCodeFromLocation(location = window.location) {
  const path = String(location.pathname || "").replace(/\/$/, "");
  const host = String(location.hostname || "").toLowerCase();

  if (host === "join.useprocess.xyz" && path) {
    const rootCode = path.replace(/^\//, "");
    if (rootCode && !["get", "telecharger", "join", "c"].includes(rootCode.toLowerCase())) {
      return normalizeAcquisitionCodeFromUrl(decodeURIComponent(rootCode));
    }
  }

  const joinMatch = path.match(/^\/join\/([^/]+)$/i);
  if (joinMatch?.[1]) {
    return normalizeAcquisitionCodeFromUrl(decodeURIComponent(joinMatch[1]));
  }

  const params = new URLSearchParams(location.search || "");
  const ref = params.get("ref") || params.get("code");
  if (ref) return normalizeAcquisitionCodeFromUrl(ref);

  return readRememberedReferralCode();
}

export function buildReferralLandingUrl(code, utm = {}) {
  const normalized = normalizeReferralCode(code);
  if (!normalized) {
    return appendParams(getAppBioShortUrl(), utm);
  }
  return appendParams(
    `https://useprocess.xyz/join/${encodeURIComponent(normalized)}`,
    utm
  );
}

export function buildCampaignLandingUrl(slug, utm = {}) {
  const clean = String(slug || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, "");
  if (!clean) return appendParams(getAppBioShortUrl(), utm);
  return appendParams(`https://useprocess.xyz/c/${encodeURIComponent(clean)}`, {
    utm_source: utm.utm_source || clean,
    utm_medium: utm.utm_medium || "campaign",
    utm_campaign: utm.utm_campaign || clean,
    ...utm,
  });
}

export function buildReferralShareText(code) {
  const normalized = normalizeReferralCode(code);
  if (!normalized) return "";
  const url = buildReferralLandingUrl(normalized);
  return appCopy(
    `Télécharge Process avec mon lien — 3 jours d’essai offerts sur l’annuel :\n${url}\n\nMon code parrainage : ${normalized}\nTu as 3 jours offerts. Je gagne 1 mois ou 1 an offert quand tu t’abonnes.`,
    `Download Process with my link — 3 free days on yearly:\n${url}\n\nMy referral code: ${normalized}\nYou get 3 free days. I earn 1 free month or year when you subscribe.`
  );
}

export function buildReferralDeepLink(code, utm = {}) {
  const normalized = normalizeReferralCode(code);
  const params = { ...utm };
  if (normalized) params.code = normalized;
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (String(value || "").trim()) query.set(key, String(value).trim());
  }
  const qs = query.toString();
  if (normalized) {
    return `process://referral${qs ? `?${qs}` : `?code=${encodeURIComponent(normalized)}`}`;
  }
  return `process://acquire${qs ? `?${qs}` : ""}`;
}

export function buildAppStoreUrlWithReferral(code, utm = {}) {
  const base = getIosAppStoreUrl();
  const normalized = normalizeReferralCode(code);
  const params = { ...utm };
  if (normalized) {
    params.ct = `ref_${normalized}`;
  } else if (utm.utm_campaign || utm.utm_source) {
    const label = String(utm.utm_campaign || utm.utm_source || "web")
      .trim()
      .replace(/\s+/g, "_")
      .slice(0, 40);
    if (label) params.ct = label;
  }
  return appendParams(base, params);
}

export function rememberReferralCode(code) {
  const normalized = normalizeAcquisitionCodeFromUrl(code) || normalizeReferralCode(code);
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
    const code = normalizeAcquisitionCodeFromUrl(localStorage.getItem(REFERRAL_STORAGE_KEY) || "");
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
