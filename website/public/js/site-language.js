(function () {
  var KEY = "process.app.language";
  var LANGS = ["fr", "en", "ja", "de", "ko", "es", "pt-BR"];
  var HTML_LANG = {
    fr: "fr",
    en: "en-US",
    ja: "ja",
    de: "de",
    ko: "ko",
    es: "es",
    "pt-BR": "pt-BR",
  };

  function normalizeLang(raw) {
    var lower = String(raw || "")
      .toLowerCase()
      .replace(/_/g, "-");
    if (lower.indexOf("fr") === 0) return "fr";
    if (lower.indexOf("ja") === 0) return "ja";
    if (lower.indexOf("de") === 0) return "de";
    if (lower.indexOf("ko") === 0) return "ko";
    if (lower.indexOf("pt") === 0) return "pt-BR";
    if (lower.indexOf("es") === 0) return "es";
    if (lower.indexOf("en") === 0) return "en";
    return null;
  }

  function prefersLanguageFromBrowser() {
    var langs = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || "fr"];
    for (var i = 0; i < langs.length; i++) {
      var mapped = normalizeLang(langs[i]);
      if (mapped) return mapped;
    }
    return "en";
  }

  function getLang() {
    var params = new URLSearchParams(window.location.search);
    var q = normalizeLang(params.get("lang"));
    if (q) return q;
    try {
      var stored = normalizeLang(localStorage.getItem(KEY));
      if (stored) return stored;
    } catch (e) {}
    return prefersLanguageFromBrowser();
  }

  function setLang(lang) {
    var normalized = normalizeLang(lang) || "fr";
    try {
      localStorage.setItem(KEY, normalized);
    } catch (e) {}
    document.documentElement.lang = HTML_LANG[normalized] || "en-US";
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
    ja: {
      home: "ホーム",
      privacy: "プライバシー",
      terms: "利用規約",
      legal: "特定商取引",
      support: "サポート",
      health: "健康ソース",
      rights: "All rights reserved.",
      chooseLang: "言語を選択",
    },
    de: {
      home: "Start",
      privacy: "Datenschutz",
      terms: "AGB",
      legal: "Impressum",
      support: "Support",
      health: "Gesundheitsquellen",
      rights: "Alle Rechte vorbehalten.",
      chooseLang: "Sprache wählen",
    },
    ko: {
      home: "홈",
      privacy: "개인정보",
      terms: "이용약관",
      legal: "법적 고지",
      support: "지원",
      health: "건강 출처",
      rights: "All rights reserved.",
      chooseLang: "언어 선택",
    },
    es: {
      home: "Inicio",
      privacy: "Privacidad",
      terms: "Términos",
      legal: "Aviso legal",
      support: "Soporte",
      health: "Fuentes de salud",
      rights: "Todos los derechos reservados.",
      chooseLang: "Elegir idioma",
    },
    "pt-BR": {
      home: "Início",
      privacy: "Privacidade",
      terms: "Termos",
      legal: "Aviso legal",
      support: "Suporte",
      health: "Fontes de saúde",
      rights: "Todos os direitos reservados.",
      chooseLang: "Escolher idioma",
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

  var cachedFrCardInner = null;

  function applyLegalBody(lang) {
    var card = document.querySelector(".card");
    if (!card || !window.LEGAL_BODY_EN) return;
    var path = window.location.pathname.replace(/\/$/, "");
    var enBody = window.LEGAL_BODY_EN[path];
    if (!enBody) return;

    if (!cachedFrCardInner) {
      cachedFrCardInner = card.innerHTML;
    }

    var page = LEGAL_PAGES[path];
    var meta = page && (page[lang] || page.en || page.fr);

    if (lang !== "fr") {
      card.innerHTML = "<h1>" + (meta ? meta.h1 : "") + "</h1>" + enBody;
    } else {
      card.innerHTML = cachedFrCardInner;
      if (meta) {
        var h1 = card.querySelector("h1");
        if (h1) h1.textContent = meta.h1;
      }
    }
  }

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
    var c = COPY[lang] || COPY.en;
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var key = el.getAttribute("data-i18n");
      if (c[key]) el.textContent = c[key];
    });
    var select = document.querySelector(".site-lang-switch select");
    if (select) select.value = lang;
    applyLegalPageMeta(lang);
    applyLegalBody(lang);
  }

  function mountSwitcher() {
    if (document.querySelector(".site-lang-switch")) return;
    var host = document.querySelector("header.site");
    if (!host) return;

    var wrap = document.createElement("label");
    wrap.className = "site-lang-switch site-lang-switch--select";
    var select = document.createElement("select");
    var choose = (COPY[getLang()] || COPY.en).chooseLang;
    select.setAttribute("aria-label", choose);
    LANGS.forEach(function (code) {
      var option = document.createElement("option");
      option.value = code;
      option.textContent = code === "pt-BR" ? "PT" : code.toUpperCase();
      select.appendChild(option);
    });
    select.value = getLang();
    select.addEventListener("change", function () {
      setLang(select.value);
    });
    wrap.appendChild(select);
    host.appendChild(wrap);
  }

  function init() {
    var params = new URLSearchParams(window.location.search);
    var fromQuery = normalizeLang(params.get("lang"));
    if (fromQuery) {
      try {
        localStorage.setItem(KEY, fromQuery);
      } catch (e) {}
    }
    var lang = getLang();
    document.documentElement.lang = HTML_LANG[lang] || "en-US";
    var card = document.querySelector(".card");
    if (card && !cachedFrCardInner) {
      cachedFrCardInner = card.innerHTML;
    }
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
