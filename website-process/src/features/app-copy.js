/** FR / EN / JA / DE / KO / ES / PT-BR — aligné sur ProcessAppLanguage (`process.app.language`). */
import {
  APP_STORE_STOREFRONT,
  SITE_LANGUAGE_CODES,
  SITE_LANGUAGES,
  normalizeSiteLanguage,
} from "./languages.js";

let catalogs = null;
let catalogsLoad = null;

function ensureCatalogs() {
  if (catalogs) return Promise.resolve(catalogs);
  if (!catalogsLoad) {
    catalogsLoad = import("../i18n/catalogs.js")
      .then((mod) => {
        catalogs = mod.catalogs || null;
        notifyLanguageChange(getSiteLanguage());
        return catalogs;
      })
      .catch(() => {
        catalogsLoad = null;
        return null;
      });
  }
  return catalogsLoad;
}

export const SITE_LANGUAGE_KEY = "process.app.language";
export { SITE_LANGUAGES, SITE_LANGUAGE_CODES };

const listeners = new Set();

function prefersLanguageFromBrowser() {
  const langs = navigator.languages?.length
    ? navigator.languages
    : [navigator.language || "fr"];
  for (const tag of langs) {
    const mapped = normalizeSiteLanguage(tag);
    if (mapped) return mapped;
  }
  return "fr";
}

/** Join / affiliate / get-app — langue = navigateur (pas de sélecteur manuel). */
export function usesAutoSiteLanguage() {
  if (typeof window === "undefined") return false;

  if (
    document.documentElement.classList.contains("page-get-app") ||
    document.documentElement.classList.contains("page-affiliate")
  ) {
    return true;
  }

  const path = window.location.pathname.replace(/\/$/, "");
  const host = window.location.hostname.toLowerCase();
  const params = new URLSearchParams(window.location.search || "");
  const hasReferral = Boolean(params.get("ref") || params.get("code"));

  if (host === "join.useprocess.xyz" || host === "get.useprocess.xyz") return true;
  if (
    path === "/clipping" ||
    path === "/clipping.html" ||
    path === "/affiliate" ||
    path === "/affiliate.html"
  ) {
    return true;
  }

  return (
    path === "/app" ||
    path === "/get" ||
    path === "/i" ||
    path === "/a" ||
    path === "/telecharger" ||
    /^\/join\/[^/]+$/i.test(path) ||
    /^\/c\/[^/]+$/i.test(path) ||
    params.get("get") === "1" ||
    hasReferral ||
    Boolean(params.get("utm_source") || params.get("utm_campaign") || params.get("source") || params.get("campaign"))
  );
}

/** Langue active : ?lang= → (auto: navigateur | landing: localStorage) → navigateur → fr. */
export function getSiteLanguage() {
  if (typeof window === "undefined") return "fr";

  const params = new URLSearchParams(window.location.search);
  const fromQuery = normalizeSiteLanguage(params.get("lang"));
  if (fromQuery) return fromQuery;

  if (usesAutoSiteLanguage()) {
    return prefersLanguageFromBrowser();
  }

  try {
    const stored = normalizeSiteLanguage(localStorage.getItem(SITE_LANGUAGE_KEY));
    if (stored) return stored;
  } catch {
    /* private mode */
  }

  return prefersLanguageFromBrowser();
}

export function prefersEnglish() {
  return getSiteLanguage() === "en";
}

export function appCopy(fr, en) {
  const lang = getSiteLanguage();
  if (lang === "fr") return fr;
  if (lang === "en") return en;
  const translated = catalogs?.[lang]?.[en];
  if (translated) return translated;
  void ensureCatalogs();
  return en;
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
  const normalized = normalizeSiteLanguage(lang) || "fr";
  try {
    localStorage.setItem(SITE_LANGUAGE_KEY, normalized);
  } catch {
    /* ignore */
  }
  applySiteDocumentLanguage(normalized);
  notifyLanguageChange(normalized);
}

const SITE_META = {
  "fr": {
    "lang": "fr",
    "title": "Process Debloat — Scan et suivi des habitudes",
    "description": "Captures du visage, journal des habitudes et coach IA. Des estimations de bien-être, sans résultat garanti.",
    "ogTitle": "Process Debloat — Scan et suivi des habitudes",
    "ogDescription": "Captures du visage, journal des habitudes et coach IA. Des estimations de bien-être, sans résultat garanti."
  },
  "en": {
    "lang": "en-US",
    "title": "Process Debloat — Scans and habit tracking",
    "description": "Face captures, a habit journal, and an AI coach. Wellness estimates with no guaranteed outcome.",
    "ogTitle": "Process Debloat — Scans and habit tracking",
    "ogDescription": "Face captures, a habit journal, and an AI coach. Wellness estimates with no guaranteed outcome."
  },
  "ja": {
    "lang": "ja",
    "title": "Process Debloat — 顔の記録と習慣の管理",
    "description": "顔の記録、習慣の日記、AIコーチ。ウェルネスの推定であり、結果を保証するものではありません。",
    "ogTitle": "Process Debloat — 顔の記録と習慣の管理",
    "ogDescription": "顔の記録、習慣の日記、AIコーチ。ウェルネスの推定であり、結果を保証するものではありません。"
  },
  "de": {
    "lang": "de",
    "title": "Process Debloat — Scans und Gewohnheiten",
    "description": "Gesichtsaufnahmen, Gewohnheitstagebuch und KI-Coach. Wellness-Schätzungen ohne garantiertes Ergebnis.",
    "ogTitle": "Process Debloat — Scans und Gewohnheiten",
    "ogDescription": "Gesichtsaufnahmen, Gewohnheitstagebuch und KI-Coach. Wellness-Schätzungen ohne garantiertes Ergebnis."
  },
  "ko": {
    "lang": "ko",
    "title": "Process Debloat — 얼굴 기록과 습관 관리",
    "description": "얼굴 기록, 습관 일지, AI 코치. 웰니스 추정치이며 결과를 보장하지 않습니다.",
    "ogTitle": "Process Debloat — 얼굴 기록과 습관 관리",
    "ogDescription": "얼굴 기록, 습관 일지, AI 코치. 웰니스 추정치이며 결과를 보장하지 않습니다."
  },
  "es": {
    "lang": "es",
    "title": "Process Debloat — Escaneos y seguimiento de hábitos",
    "description": "Capturas faciales, diario de hábitos y coach de IA. Estimaciones de bienestar sin resultados garantizados.",
    "ogTitle": "Process Debloat — Escaneos y seguimiento de hábitos",
    "ogDescription": "Capturas faciales, diario de hábitos y coach de IA. Estimaciones de bienestar sin resultados garantizados."
  },
  "pt-BR": {
    "lang": "pt-BR",
    "title": "Process Debloat — Registros e acompanhamento de hábitos",
    "description": "Registros do rosto, diário de hábitos e coach de IA. Estimativas de bem-estar sem resultados garantidos.",
    "ogTitle": "Process Debloat — Registros e acompanhamento de hábitos",
    "ogDescription": "Registros do rosto, diário de hábitos e coach de IA. Estimativas de bem-estar sem resultados garantidos."
  }
};

export function applySiteDocumentLanguage(lang = getSiteLanguage()) {
  const normalized = normalizeSiteLanguage(lang) || "fr";
  const meta = SITE_META[normalized] || SITE_META.en;
  document.documentElement.lang = meta.lang;

  if (!document.documentElement.classList.contains("page-affiliate")) {
    document.title = meta.title;
  }

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
  const fromQuery = normalizeSiteLanguage(params.get("lang"));
  if (fromQuery) {
    try {
      localStorage.setItem(SITE_LANGUAGE_KEY, fromQuery);
    } catch {
      /* ignore */
    }
  }
  const lang = getSiteLanguage();
  if (lang !== "fr" && lang !== "en") void ensureCatalogs();
  applySiteDocumentLanguage(lang);
}

export function siteStorefront() {
  return APP_STORE_STOREFRONT[getSiteLanguage()] || "us";
}
