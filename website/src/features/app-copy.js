/** FR / US English — aligné sur ProcessAppLanguage (`process.app.language`). */
export const SITE_LANGUAGE_KEY = "process.app.language";

const listeners = new Set();

function prefersEnglishFromBrowser() {
  const langs = navigator.languages?.length
    ? navigator.languages
    : [navigator.language || "fr"];
  for (const tag of langs) {
    const lower = String(tag).toLowerCase();
    if (lower.startsWith("fr")) return false;
    if (lower.startsWith("en")) return true;
  }
  return false;
}

/** Langue active du site : ?lang= → localStorage → navigateur. */
export function getSiteLanguage() {
  if (typeof window === "undefined") return "fr";

  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("lang");
  if (fromQuery === "fr" || fromQuery === "en") return fromQuery;

  try {
    const stored = localStorage.getItem(SITE_LANGUAGE_KEY);
    if (stored === "fr" || stored === "en") return stored;
  } catch {
    /* private mode */
  }

  return prefersEnglishFromBrowser() ? "en" : "fr";
}

export function prefersEnglish() {
  return getSiteLanguage() === "en";
}

export function appCopy(fr, en) {
  return prefersEnglish() ? en : fr;
}

export function subscribeSiteLanguage(callback) {
  listeners.add(callback);
  return () => listeners.delete(callback);
}

function notifyLanguageChange(lang) {
  for (const cb of listeners) cb(lang);
  window.dispatchEvent(new CustomEvent("process:language-change", { detail: lang }));
}

/** Persiste la langue, met à jour `<html lang>` + meta, notifie React. */
export function setSiteLanguage(lang) {
  const normalized = lang === "en" ? "en" : "fr";
  try {
    localStorage.setItem(SITE_LANGUAGE_KEY, normalized);
  } catch {
    /* ignore */
  }
  applySiteDocumentLanguage(normalized);
  notifyLanguageChange(normalized);
}

const SITE_META = {
  fr: {
    lang: "fr",
    title: "Process — Coach IA & protocole debloat visage",
    description:
      "Process — Coach IA, scan visage et protocole debloat personnalisé. Dégonfle ton visage avec nutrition, hydratation et suivi Apple Santé.",
    ogTitle: "Process — Coach IA & protocole debloat",
    ogDescription: "Coach IA, scan visage et protocole debloat — application iOS.",
  },
  en: {
    lang: "en-US",
    title: "Process — AI Coach & Face Debloat Protocol",
    description:
      "Process — AI coach, face scan and personalized debloat protocol. Debloat your face with nutrition, hydration and Apple Health tracking.",
    ogTitle: "Process — AI Coach & Face Debloat",
    ogDescription: "AI coach, face scan and debloat protocol — iOS app.",
  },
};

export function applySiteDocumentLanguage(lang = getSiteLanguage()) {
  const normalized = lang === "en" ? "en" : "fr";
  const meta = SITE_META[normalized];
  document.documentElement.lang = meta.lang;

  document.title = meta.title;

  const desc = document.querySelector('meta[name="description"]');
  if (desc) desc.setAttribute("content", meta.description);

  const ogTitle = document.querySelector('meta[property="og:title"]');
  if (ogTitle) ogTitle.setAttribute("content", meta.ogTitle);

  const ogDesc = document.querySelector('meta[property="og:description"]');
  if (ogDesc) ogDesc.setAttribute("content", meta.ogDescription);
}

/** À appeler au boot avant le montage React. */
export function initSiteLanguage() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("lang");
  if (fromQuery === "fr" || fromQuery === "en") {
    try {
      localStorage.setItem(SITE_LANGUAGE_KEY, fromQuery);
    } catch {
      /* ignore */
    }
  }
  applySiteDocumentLanguage(getSiteLanguage());
}
