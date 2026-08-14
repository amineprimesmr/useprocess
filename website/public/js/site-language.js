(function () {
  var KEY = "process.app.language";

  function prefersEnglishFromBrowser() {
    var langs = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || "fr"];
    for (var i = 0; i < langs.length; i++) {
      var lower = String(langs[i]).toLowerCase();
      if (lower.indexOf("fr") === 0) return false;
      if (lower.indexOf("en") === 0) return true;
    }
    return false;
  }

  function getLang() {
    var params = new URLSearchParams(window.location.search);
    var q = params.get("lang");
    if (q === "fr" || q === "en") return q;
    try {
      var stored = localStorage.getItem(KEY);
      if (stored === "fr" || stored === "en") return stored;
    } catch (e) {}
    return prefersEnglishFromBrowser() ? "en" : "fr";
  }

  function setLang(lang) {
    var normalized = lang === "en" ? "en" : "fr";
    try {
      localStorage.setItem(KEY, normalized);
    } catch (e) {}
    document.documentElement.lang = normalized === "en" ? "en-US" : "fr";
    applyCopy(normalized);
    window.dispatchEvent(new CustomEvent("process:language-change", { detail: normalized }));
  }

  var COPY = {
    fr: {
      home: "Accueil",
      privacy: "Confidentialité",
      terms: "CGU",
      legal: "Mentions légales",
      support: "Support",
      health: "Sources santé",
      rights: "Tous droits réservés.",
      chooseLang: "Choisir la langue",
    },
    en: {
      home: "Home",
      privacy: "Privacy",
      terms: "Terms",
      legal: "Legal notice",
      support: "Support",
      health: "Health sources",
      rights: "All rights reserved.",
      chooseLang: "Choose language",
    },
  };

  var LEGAL_PAGES = {
    "/cgu": {
      fr: {
        title: "Conditions d'utilisation — Process AI",
        description: "Conditions générales d'utilisation de l'application Process AI.",
        h1: "Conditions d'utilisation",
      },
      en: {
        title: "Terms of Service — Process AI",
        description: "Terms of use for the Process AI iOS application.",
        h1: "Terms of Service",
      },
    },
    "/confidentialite": {
      fr: {
        title: "Politique de confidentialité — Process AI",
        description: "Politique de confidentialité de l'application Process AI.",
        h1: "Politique de confidentialité",
      },
      en: {
        title: "Privacy Policy — Process AI",
        description: "Privacy policy for the Process AI iOS application.",
        h1: "Privacy Policy",
      },
    },
    "/mentions-legales": {
      fr: {
        title: "Mentions légales — Process AI",
        description: "Mentions légales du site useprocess.xyz et de l'application Process AI.",
        h1: "Mentions légales",
      },
      en: {
        title: "Legal Notice — Process AI",
        description: "Legal notice for useprocess.xyz and the Process AI application.",
        h1: "Legal Notice",
      },
    },
    "/support": {
      fr: {
        title: "Support — Process AI",
        description: "Contactez le support Process AI pour l'application iOS, l'abonnement ou vos données.",
        h1: "Support",
      },
      en: {
        title: "Support — Process AI",
        description: "Contact Process AI support for the iOS app, subscription, or your data.",
        h1: "Support",
      },
    },
    "/sources-sante": {
      fr: {
        title: "Sources santé — Process AI",
        description: "Sources et références médicales citées dans Process AI (OMS, CDC, NIH, Apple Santé).",
        h1: "Sources et références santé",
      },
      en: {
        title: "Health Sources — Process AI",
        description: "Medical sources and references cited in Process AI (WHO, CDC, NIH, Apple Health).",
        h1: "Health sources and references",
      },
    },
  };

  function applyLegalPageMeta(lang) {
    var path = window.location.pathname.replace(/\/$/, "");
    var page = LEGAL_PAGES[path];
    if (!page) return;

    var meta = page[lang] || page.fr;
    document.title = meta.title;

    var desc = document.querySelector('meta[name="description"]');
    if (desc) desc.setAttribute("content", meta.description);

    var h1 = document.querySelector(".card h1");
    if (h1) h1.textContent = meta.h1;
  }

  function applyCopy(lang) {
    var c = COPY[lang] || COPY.fr;
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var key = el.getAttribute("data-i18n");
      if (c[key]) el.textContent = c[key];
    });
    document.querySelectorAll(".site-lang-switch button").forEach(function (btn) {
      var active = btn.getAttribute("data-lang") === lang;
      btn.classList.toggle("is-active", active);
      btn.setAttribute("aria-pressed", active ? "true" : "false");
    });
    applyLegalPageMeta(lang);
  }

  function mountSwitcher() {
    if (document.querySelector(".site-lang-switch")) return;
    var host = document.querySelector("header.site");
    if (!host) return;

    var wrap = document.createElement("div");
    wrap.className = "site-lang-switch";
    wrap.setAttribute("role", "group");
    wrap.setAttribute("aria-label", COPY[getLang()].chooseLang);

    ["fr", "en"].forEach(function (code) {
      var btn = document.createElement("button");
      btn.type = "button";
      btn.setAttribute("data-lang", code);
      btn.textContent = code.toUpperCase();
      btn.addEventListener("click", function () {
        setLang(code);
      });
      wrap.appendChild(btn);
    });

    host.appendChild(wrap);
  }

  function init() {
    var params = new URLSearchParams(window.location.search);
    var fromQuery = params.get("lang");
    if (fromQuery === "fr" || fromQuery === "en") {
      try {
        localStorage.setItem(KEY, fromQuery);
      } catch (e) {}
    }
    var lang = getLang();
    document.documentElement.lang = lang === "en" ? "en-US" : "fr";
    mountSwitcher();
    applyCopy(lang);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  window.ProcessSiteLanguage = { getLang: getLang, setLang: setLang };
})();
