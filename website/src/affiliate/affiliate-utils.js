import { appCopy } from "../features/app-copy.js";

import { normalizeAcquisitionCode, parseAcquisitionCodeFromInput } from "../features/acquisition-link.js";
import { FUNCTIONS_BASE } from "../features/firebase-client.js";

export const SUPPORT_EMAIL = "support@useprocess.xyz";
export const AFFILIATE_X_HANDLE = "leksoudblt";
export const AFFILIATE_X_DM_URL = `https://x.com/messages/compose?screen_name=${AFFILIATE_X_HANDLE}`;
export const COMMISSION_PERCENT = 40;
export const HOLD_DAYS = 30;

/** Cash view bonuses on top of lifetime commission — cumulative per video, capped. */
export const VIEW_BONUS_TIERS = [
  { amountUsd: 20, views: 40_000 },
  { amountUsd: 30, views: 100_000 },
  { amountUsd: 100, views: 500_000 },
  { amountUsd: 150, views: 1_000_000 },
];
export const VIEW_BONUS_MAX_PER_VIDEO_USD = 300;
export const VIEW_BONUS_ELIGIBILITY = {
  minViews28d: 500_000,
  minVideos: 5,
  windowDays: 28,
};

export function formatViewCount(views) {
  const n = Number(views) || 0;
  if (n >= 1_000_000) {
    const millions = n / 1_000_000;
    return Number.isInteger(millions) ? `${millions}M` : `${millions.toFixed(1)}M`;
  }
  if (n >= 1_000) {
    const thousands = n / 1_000;
    return Number.isInteger(thousands) ? `${thousands}k` : `${Math.round(thousands)}k`;
  }
  return String(n);
}

export function viewBonusUsdForViews(views) {
  const n = Number(views) || 0;
  let total = 0;
  for (const tier of VIEW_BONUS_TIERS) {
    if (n >= tier.views) total += tier.amountUsd;
  }
  return Math.min(total, VIEW_BONUS_MAX_PER_VIDEO_USD);
}

export function viewBonusEligibilityLabel() {
  const views = formatViewCount(VIEW_BONUS_ELIGIBILITY.minViews28d);
  const days = VIEW_BONUS_ELIGIBILITY.windowDays;
  const videos = VIEW_BONUS_ELIGIBILITY.minVideos;
  return appCopy(
    `${views}+ vues / ${days}j • ${videos}+ vidéos`,
    `${views}+ views / ${days}d • ${videos}+ videos`
  );
}

export function viewBonusCapLabel() {
  return appCopy(
    `$${VIEW_BONUS_MAX_PER_VIDEO_USD} max par vidéo`,
    `$${VIEW_BONUS_MAX_PER_VIDEO_USD} max per video`
  );
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isValidEmail(raw) {
  const value = String(raw || "").trim();
  return Boolean(value && EMAIL_PATTERN.test(value));
}

export function validateEmailFormat(raw) {
  const value = String(raw || "").trim();
  if (!value) {
    return {
      ok: false,
      error: appCopy("Email requis.", "Email is required."),
    };
  }
  if (!EMAIL_PATTERN.test(value)) {
    return {
      ok: false,
      error: appCopy("Email invalide.", "Invalid email address."),
    };
  }
  return { ok: true, error: "" };
}

export function validateAffiliateCodeFormat(raw) {
  const normalized = parseAcquisitionCodeFromInput(raw);
  if (!normalized || normalized.length < 3) {
    return {
      ok: false,
      normalized: normalized || "",
      error: appCopy(
        "Code invalide — minimum 3 caractères (lettres, chiffres ou tiret).",
        "Invalid code — at least 3 characters (letters, numbers, or hyphen)."
      ),
    };
  }
  return { ok: true, normalized, error: "" };
}

export async function checkAffiliateCodeAvailability(raw, { uid } = {}) {
  const format = validateAffiliateCodeFormat(raw);
  if (!format.ok) return format;

  try {
    const response = await fetch(`${FUNCTIONS_BASE}/affiliateResolveCode`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ code: format.normalized }),
    });

    if (response.status === 404) {
      return { ok: true, normalized: format.normalized, error: "" };
    }

    if (response.ok) {
      const data = await response.json();

      // Referral codes live in a separate namespace — backend only blocks affiliateCodes.
      if (data?.type === "referral") {
        return { ok: true, normalized: format.normalized, error: "" };
      }

      // Active affiliate clipper code owned by someone else.
      if (data?.type === "affiliate") {
        if (uid && data.affiliateId === uid) {
          return { ok: true, normalized: format.normalized, error: "" };
        }
        return {
          ok: false,
          normalized: format.normalized,
          error: appCopy(
            "Ce code est déjà pris — essaie une variante (ex. MANNY2).",
            "This code is already taken — try a variant (e.g. MANNY2)."
          ),
        };
      }
    }
  } catch {
    /* offline: format-only validation */
  }

  return { ok: true, normalized: format.normalized, error: "" };
}

export function formatApplyError(error) {
  const code = error?.code || "";
  const message = error?.data?.error || error?.message || "";

  if (code.startsWith("auth/")) return formatAuthError(error);
  if (message === "CODE_CONFLICT") {
    return appCopy(
      "Ce code est déjà pris — essaie une autre variante.",
      "This code is already taken — try another variant."
    );
  }
  if (message === "APPLY_TIMEOUT" || message === "AUTH_TIMEOUT" || message === "TIMEOUT") {
    return appCopy(
      "Ça a pris trop de temps. Réessaie.",
      "That took too long. Try again."
    );
  }
  if (message === "INVALID_CODE") {
    return appCopy(
      "Code invalide — minimum 3 caractères (lettres, chiffres ou tiret).",
      "Invalid code — at least 3 characters (letters, numbers, or hyphen)."
    );
  }
  return message || appCopy("Échec de la candidature.", "Application failed.");
}

export function formatAuthError(error) {
  const code = error?.code || "";
  const map = {
    "auth/invalid-email": appCopy("Email invalide.", "Invalid email address."),
    "auth/user-disabled": appCopy("Compte désactivé.", "This account has been disabled."),
    "auth/user-not-found": appCopy("Aucun compte avec cet email.", "No account found for this email."),
    "auth/wrong-password": appCopy("Mot de passe incorrect.", "Incorrect password."),
    "auth/invalid-credential": appCopy("Email ou mot de passe incorrect.", "Incorrect email or password."),
    "auth/email-already-in-use": appCopy("Cet email est déjà utilisé.", "This email is already in use."),
    "auth/weak-password": appCopy("Mot de passe trop faible (6 caractères min.).", "Password too weak (min. 6 characters)."),
    "auth/too-many-requests": appCopy("Trop de tentatives. Réessaie dans quelques minutes.", "Too many attempts. Try again in a few minutes."),
    "auth/network-request-failed": appCopy("Erreur réseau. Vérifie ta connexion.", "Network error. Check your connection."),
    "auth/operation-not-allowed": appCopy(
      "Connexion email non activée côté Firebase.",
      "Email sign-in is not enabled in Firebase."
    ),
  };
  return map[code] || error?.message || appCopy("Erreur de connexion.", "Sign-in failed.");
}

export function existingAccountPrompt() {
  return appCopy(
    "Compte Process déjà existant — connecte-toi pour envoyer ta candidature.",
    "Process account already exists — log in to submit your application."
  );
}

export function existingAccountOAuthHint() {
  return appCopy(
    "Connexion Apple ou Google détectée. Ouvre l'app Process, ou définis un mot de passe dans Réglages → Compte.",
    "Apple or Google sign-in detected. Open the Process app, or set a password in Settings → Account."
  );
}

export function passwordResetSentMessage(email) {
  return appCopy(
    `Email de réinitialisation envoyé à ${email}.`,
    `Password reset email sent to ${email}.`
  );
}

export function passwordResetErrorMessage() {
  return appCopy(
    "Impossible d'envoyer l'email. Vérifie l'adresse ou réessaie.",
    "Couldn't send the email. Check the address or try again."
  );
}

export function money(cents, currency = "EUR") {
  try {
    return new Intl.NumberFormat(undefined, {
      style: "currency",
      currency,
      maximumFractionDigits: 2,
    }).format((cents || 0) / 100);
  } catch {
    return `${((cents || 0) / 100).toFixed(2)} ${currency}`;
  }
}

export function supportMailto(subject, body) {
  const params = new URLSearchParams();
  if (subject) params.set("subject", subject);
  if (body) params.set("body", body);
  const query = params.toString();
  return `mailto:${SUPPORT_EMAIL}${query ? `?${query}` : ""}`;
}

export function readHashRoute() {
  const raw = (window.location.hash || "").replace(/^#\/?/, "");
  const route = raw.split("?")[0]?.trim();
  return route || "program";
}

export function readHashQuery() {
  const raw = (window.location.hash || "").replace(/^#\/?/, "");
  const query = raw.split("?")[1];
  if (!query) return {};
  return Object.fromEntries(new URLSearchParams(query));
}

export const AFFILIATE_ROUTE_ALIASES = {
  links: "overview",
  earnings: "overview",
  methodes: "methode",
  methods: "methode",
  automation: "automatisation",
  usa: "us",
  "poster-us": "us",
  "tiktok-us": "us",
};

export const AFFILIATE_DASHBOARD_ROUTES = new Set([
  "overview",
  "formats",
  "methode",
  "automatisation",
  "us",
  "payouts",
  "settings",
]);

export function canonicalizeAffiliateRoute(route, query = {}) {
  const raw = String(route || "").trim();
  const aliased = AFFILIATE_ROUTE_ALIASES[raw] || raw;
  const moduleKey = String(query.m || "").trim();
  if (aliased === "methode" && (moduleKey === "7" || moduleKey === "formats")) {
    return "formats";
  }
  return aliased;
}

const AFFILIATE_PREFILL_STORAGE_KEY = "process.affiliate.applyPrefill";

export function readAffiliatePrefillFromLocation() {
  const hashQuery = readHashQuery();
  const search = Object.fromEntries(new URLSearchParams(window.location.search || ""));

  return {
    from: String(hashQuery.from || search.from || "").trim(),
    name: String(hashQuery.name || search.name || "").trim(),
    code: parseAcquisitionCodeFromInput(hashQuery.code || search.code || ""),
    email: String(hashQuery.email || search.email || "").trim(),
  };
}

export function hasAffiliatePrefill(prefill) {
  if (!prefill) return false;
  return Boolean(prefill.name || prefill.code || prefill.email);
}

export function storeAffiliatePrefill(prefill) {
  if (!hasAffiliatePrefill(prefill)) return;

  try {
    sessionStorage.setItem(
      AFFILIATE_PREFILL_STORAGE_KEY,
      JSON.stringify({
        from: String(prefill.from || "").trim(),
        name: String(prefill.name || "").trim(),
        code: normalizeAcquisitionCode(prefill.code || ""),
        email: String(prefill.email || "").trim(),
      })
    );
  } catch {
    /* ignore quota / private mode */
  }
}

export function readStoredAffiliatePrefill() {
  try {
    const raw = sessionStorage.getItem(AFFILIATE_PREFILL_STORAGE_KEY);
    if (!raw) return null;

    const data = JSON.parse(raw);
    const prefill = {
      from: String(data?.from || "").trim(),
      name: String(data?.name || "").trim(),
        code: parseAcquisitionCodeFromInput(data?.code || ""),
      email: String(data?.email || "").trim(),
    };

    return hasAffiliatePrefill(prefill) ? prefill : null;
  } catch {
    return null;
  }
}

export function clearAffiliatePrefillFromLocation() {
  try {
    const url = new URL(window.location.href);
    for (const key of ["name", "code", "email", "from"]) {
      url.searchParams.delete(key);
    }
    const next = `${url.pathname}${url.search}${url.hash}`;
    window.history.replaceState(null, "", next);
  } catch {
    /* ignore */
  }
}

export function consumeAffiliatePrefill() {
  const fromLocation = readAffiliatePrefillFromLocation();
  const hadPrefill = hasAffiliatePrefill(fromLocation);
  if (hadPrefill) {
    storeAffiliatePrefill(fromLocation);
    clearAffiliatePrefillFromLocation();
  }
  return readStoredAffiliatePrefill();
}

export function navigateHash(route) {
  const next = route.startsWith("#") ? route : `#/${route}`;
  if (window.location.hash !== next) {
    window.location.hash = next;
  }
}

export function formatShortDate(ms) {
  if (!ms) return "—";
  try {
    return new Intl.DateTimeFormat(undefined, {
      weekday: "short",
      month: "short",
      day: "numeric",
    }).format(new Date(ms));
  } catch {
    return new Date(ms).toLocaleDateString();
  }
}

export function buildSocialMailBody(displayName, handle) {
  return appCopy(
    `Bonjour,\n\nMon @ TikTok/Instagram : ${handle}\nPrénom : ${displayName || ""}\n\nMerci !`,
    `Hi,\n\nMy TikTok/Instagram @: ${handle}\nFirst name: ${displayName || ""}\n\nThanks!`
  );
}

export function socialMailSubject() {
  return appCopy("Profil TikTok/Instagram — Process créateur", "TikTok/Instagram profile — Process creator");
}

export function buildSupportBody(displayName) {
  return appCopy(
    `Bonjour,\n\nJe viens de candidater au programme créateur Process (${displayName || ""}).\nProfil TikTok / réseaux : \n\nMerci !`,
    `Hi,\n\nI just applied to the Process creator program (${displayName || ""}).\nTikTok / social profile: \n\nThanks!`
  );
}
