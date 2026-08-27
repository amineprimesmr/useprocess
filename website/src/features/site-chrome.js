import { getSiteLanguage, setSiteLanguage, subscribeSiteLanguage, appCopy } from "./app-copy.js";
import { SITE_LANGUAGES, normalizeSiteLanguage } from "./languages.js";

export function notFoundCopy() {
  return {
    title: appCopy("Page introuvable", "Page not found"),
    back: appCopy("Retour à l'accueil", "Back to home"),
  };
}

export function getAppPageCopy() {
  return {
    title: appCopy("Télécharge Process et dégonfle ton visage.", "Download Process and debloat your face."),
    subtitle: appCopy(
      "Process — coach IA & protocole debloat. Sur iPhone.",
      "Process — AI coach & debloat protocol. On iPhone."
    ),
    guestLabelReferral: appCopy("Invitation parrainage", "Referral invite"),
    guestLabelCreator: appCopy("Invitation clipper", "Clipper invite"),
    guestValue: appCopy("Coach IA & protocole debloat", "AI coach & debloat protocol"),
    friendInvitesTitle: appCopy("Un ami t'invite sur Process", "Your friend invites you to Process"),
    friendInvitesTitleNamed: (name) =>
      appCopy(`${name} t'invite sur Process`, `${name} invites you to Process`),
    creatorInvitesTitle: appCopy("Un clipper t'invite sur Process", "A clipper invites you to Process"),
    creatorInvitesTitleNamed: (name) =>
      appCopy(`${name} t'invite sur Process`, `${name} invites you to Process`),
    invitedSubtitle: appCopy(
      "3 jours d’essai offerts sur l’annuel. Télécharge l’app et entre le code.",
      "3 free days on yearly. Get the app and enter the code."
    ),
    creatorSubtitle: appCopy(
      "3 jours d’essai offerts sur l’annuel avec ce code clipper.",
      "3 free days on yearly with this clipper code."
    ),
    tapBanner: appCopy("Tapote la bannière pour commencer", "Tap the banner to start"),
    stepsHeading: appCopy("Comment commencer", "How to get started"),
    stepsFallbackHeading: appCopy("Tu ne vois pas la bannière ?", "Don't see the banner?"),
    stepQr: appCopy("Scanne le QR code avec ton iPhone", "Scan QR Code with your iPhone"),
    stepCodePrefix: appCopy("Ton code parrainage :", "Your referral code is"),
    stepCreatorCodePrefix: appCopy("Ton code clipper :", "Your clipper code is"),
    stepBenefitReferral: appCopy(
      "3 jours d’essai offerts sur l’annuel avec le code de ton ami",
      "3 free days on yearly with your friend's code"
    ),
    stepBenefitCreator: appCopy(
      "3 jours d’essai offerts sur l’annuel avec ce code clipper",
      "3 free days on yearly with this clipper code"
    ),
    stepDownload: appCopy("Télécharge l'app", "Download the app"),
    iosEyebrow: appCopy("Télécharger sur", "Download on"),
    iosAria: appCopy("Télécharger sur App Store", "Download on App Store"),
    langAria: appCopy("Choisir la langue", "Choose language"),
  };
}

const GET_APP_META = {
  fr: {
    title: "Télécharger Process — Coach IA debloat",
    description: "Télécharge Process sur iPhone. Coach IA, scan visage et protocole debloat personnalisé.",
    htmlLang: "fr",
  },
  en: {
    title: "Download Process — AI Debloat Coach",
    description: "Download Process on iPhone. AI coach, face scan and personalized debloat protocol.",
    htmlLang: "en-US",
  },
  ja: {
    title: "Process をダウンロード — AIデブロートコーチ",
    description: "iPhoneでProcessをダウンロード。AIコーチ、顔スキャン、あなた専用のデブロートプロトコル。",
    htmlLang: "ja",
  },
  de: {
    title: "Process laden — KI-Debloat-Coach",
    description: "Lade Process aufs iPhone. KI-Coach, Gesichtsscan und persönliches Debloat-Protokoll.",
    htmlLang: "de",
  },
  ko: {
    title: "Process 다운로드 — AI 디블로트 코치",
    description: "iPhone에서 Process를 다운로드하세요. AI 코치, 얼굴 스캔, 맞춤 디블로트 프로토콜.",
    htmlLang: "ko",
  },
  es: {
    title: "Descarga Process — Coach IA debloat",
    description: "Descarga Process en iPhone. Coach IA, escáner facial y protocolo debloat personalizado.",
    htmlLang: "es",
  },
  "pt-BR": {
    title: "Baixe o Process — Coach de IA debloat",
    description: "Baixe o Process no iPhone. Coach de IA, scan facial e protocolo debloat personalizado.",
    htmlLang: "pt-BR",
  },
};

export function applyGetAppDocumentLanguage(lang = getSiteLanguage()) {
  const normalized = normalizeSiteLanguage(lang) || "fr";
  const meta = GET_APP_META[normalized] || GET_APP_META.en;
  document.documentElement.lang = meta.htmlLang;
  document.title = meta.title;
  const desc = document.querySelector('meta[name="description"]');
  if (desc) desc.setAttribute("content", meta.description);
}

export function mountLanguageSwitch(container, { compact = false } = {}) {
  if (!container || container.querySelector(".site-lang-switch")) return () => {};

  const wrap = document.createElement("label");
  wrap.className = `site-lang-switch site-lang-switch--select${compact ? " site-lang-switch--compact" : ""}`;

  const select = document.createElement("select");
  select.setAttribute("aria-label", getAppPageCopy().langAria);
  for (const item of SITE_LANGUAGES) {
    const option = document.createElement("option");
    option.value = item.code;
    option.textContent = item.label;
    select.appendChild(option);
  }
  select.addEventListener("change", () => setSiteLanguage(select.value));
  wrap.appendChild(select);
  container.appendChild(wrap);

  const sync = (lang) => {
    select.value = lang;
  };

  sync(getSiteLanguage());
  return subscribeSiteLanguage(sync);
}

export function applyNotFoundCopy() {
  const copy = notFoundCopy();
  const root = document.getElementById("page-404");
  if (!root) return;
  const h1 = root.querySelector("h1");
  const link = root.querySelector("a");
  if (h1) h1.textContent = copy.title;
  if (link) link.textContent = copy.back;
}

export function landingFooterCopy() {
  return {
    terms: appCopy("CGU", "Terms"),
    privacy: appCopy("Confidentialité", "Privacy"),
    support: appCopy("Support", "Support"),
    health: appCopy("Sources santé", "Health sources"),
  };
}

export function applyLandingFooterCopy() {
  const copy = landingFooterCopy();
  const aria = appCopy("Liens pied de page", "Footer links");
  const footerNav = document.querySelector("#site-footer-process .landing-footer-sf-nav");
  if (footerNav) footerNav.setAttribute("aria-label", aria);
  const links = document.querySelectorAll("#site-footer-process .landing-footer-sf-nav a");
  const keys = ["terms", "privacy", "support", "health"];
  links.forEach((link, index) => {
    const key = keys[index];
    if (key && copy[key]) link.textContent = copy[key];
  });
}

export function applyGetAppChromeCopy() {
  const back = document.querySelector("#landing-legal .landing-btn-secondary");
  if (back) back.textContent = appCopy("← Retour", "← Back");
}
