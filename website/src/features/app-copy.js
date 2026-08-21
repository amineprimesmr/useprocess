/** FR / EN / JA / DE / KO / ES / PT-BR — aligné sur ProcessAppLanguage (`process.app.language`). */
import { catalogs } from "../i18n/catalogs.js";
import {
  APP_STORE_STOREFRONT,
  SITE_LANGUAGE_CODES,
  SITE_LANGUAGES,
  normalizeSiteLanguage,
} from "./languages.js";

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
  if (path === "/affiliate" || path === "/affiliate.html") return true;

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
  return catalogs[lang]?.[en] || en;
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
  ja: {
    lang: "ja",
    title: "Process — AIコーチ＆顔のむくみプロトコル",
    description:
      "Process — AIコーチ、顔スキャン、あなた専用のデブロートプロトコル。栄養・水分・Appleヘルスケアで顔のむくみを落とす。",
    ogTitle: "Process — AIコーチ＆顔デブロート",
    ogDescription: "AIコーチ、顔スキャン、デブロートプロトコル — iOSアプリ。",
  },
  de: {
    lang: "de",
    title: "Process — KI-Coach & Gesicht-Debloat-Protokoll",
    description:
      "Process — KI-Coach, Gesichtsscan und persönliches Debloat-Protokoll. Reduziere Schwellungen mit Ernährung, Hydration und Apple Health.",
    ogTitle: "Process — KI-Coach & Gesicht-Debloat",
    ogDescription: "KI-Coach, Gesichtsscan und Debloat-Protokoll — iOS-App.",
  },
  ko: {
    lang: "ko",
    title: "Process — AI 코치 & 얼굴 디블로트 프로토콜",
    description:
      "Process — AI 코치, 얼굴 스캔, 맞춤 디블로트 프로토콜. 영양, 수분, Apple 건강으로 얼굴 붓기를 빼세요.",
    ogTitle: "Process — AI 코치 & 얼굴 디블로트",
    ogDescription: "AI 코치, 얼굴 스캔, 디블로트 프로토콜 — iOS 앱.",
  },
  es: {
    lang: "es",
    title: "Process — Coach IA y protocolo debloat facial",
    description:
      "Process — Coach IA, escáner facial y protocolo debloat personalizado. Reduce la hinchazón con nutrición, hidratación y Apple Health.",
    ogTitle: "Process — Coach IA y debloat facial",
    ogDescription: "Coach IA, escáner facial y protocolo debloat — app iOS.",
  },
  "pt-BR": {
    lang: "pt-BR",
    title: "Process — Coach de IA e protocolo debloat facial",
    description:
      "Process — Coach de IA, scan facial e protocolo debloat personalizado. Desinche o rosto com nutrição, hidratação e Apple Saúde.",
    ogTitle: "Process — Coach de IA e debloat facial",
    ogDescription: "Coach de IA, scan facial e protocolo debloat — app iOS.",
  },
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
  applySiteDocumentLanguage(getSiteLanguage());
}

export function siteStorefront() {
  return APP_STORE_STOREFRONT[getSiteLanguage()] || "us";
}
