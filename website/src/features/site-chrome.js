import { getSiteLanguage, setSiteLanguage, subscribeSiteLanguage, appCopy, applySiteDocumentLanguage } from "./app-copy.js";

export function notFoundCopy() {
  return {
    title: appCopy("Page introuvable", "Page not found"),
    back: appCopy("Retour à l'accueil", "Back to home"),
  };
}

export function getAppPageCopy() {
  return {
    title: appCopy("Téléchargez Process et dégonflez votre visage.", "Download Process and de-bloat your face."),
    subtitle: appCopy(
      "Process — coach IA & protocole debloat. Télécharge sur iPhone.",
      "Process — AI coach & debloat protocol. Download on iPhone."
    ),
    invitedTitle: appCopy("Tu es invité sur Process.", "You're invited to Process."),
    invitedSubtitle: appCopy(
      "Code actif — télécharge Process et commence ton protocole.",
      "Code active — download Process and start your protocol."
    ),
    referralEyebrow: appCopy("Invitation parrainage", "Referral invite"),
    iosEyebrow: appCopy("Télécharger sur", "Download on"),
    iosAria: appCopy("Télécharger sur App Store", "Download on App Store"),
    langAria: appCopy("Choisir la langue", "Choose language"),
  };
}

const GET_APP_META = {
  fr: {
    title: "Télécharger Process — Coach IA debloat",
    description: "Télécharge Process sur iPhone. Coach IA, scan visage et protocole debloat personnalisé.",
  },
  en: {
    title: "Download Process — AI Debloat Coach",
    description: "Download Process on iPhone. AI coach, face scan and personalized debloat protocol.",
  },
};

export function applyGetAppDocumentLanguage(lang) {
  const normalized = lang === "en" ? "en" : "fr";
  const meta = GET_APP_META[normalized];
  document.title = meta.title;
  const desc = document.querySelector('meta[name="description"]');
  if (desc) desc.setAttribute("content", meta.description);
  applySiteDocumentLanguage(normalized);
}

export function mountLanguageSwitch(container, { compact = false } = {}) {
  if (!container || container.querySelector(".site-lang-switch")) return () => {};

  const wrap = document.createElement("div");
  wrap.className = `site-lang-switch${compact ? " site-lang-switch--compact" : ""}`;
  wrap.setAttribute("role", "group");
  wrap.setAttribute("aria-label", getAppPageCopy().langAria);

  for (const code of ["fr", "en"]) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.dataset.lang = code;
    btn.textContent = code.toUpperCase();
    btn.addEventListener("click", () => setSiteLanguage(code));
    wrap.appendChild(btn);
  }

  container.appendChild(wrap);

  const sync = (lang) => {
    wrap.querySelectorAll("button").forEach((btn) => {
      const active = btn.dataset.lang === lang;
      btn.classList.toggle("is-active", active);
      btn.setAttribute("aria-pressed", String(active));
    });
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
  const links = document.querySelectorAll("#site-footer-process .landing-footer-sf-nav a");
  const keys = ["terms", "privacy", "support", "health"];
  links.forEach((link, index) => {
    const key = keys[index];
    if (key && copy[key]) link.textContent = copy[key];
  });
}
