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
      legal: "法的表記",
      support: "サポート",
      health: "健康ソース",
      rights: "無断転載を禁じます。",
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
      rights: "무단 전재를 금합니다.",
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
      ja: {
        title: "利用規約 — Process AI",
        description: "Process AI iOSアプリの利用規約。",
        h1: "利用規約",
      },
      de: {
        title: "Nutzungsbedingungen — Process AI",
        description: "Nutzungsbedingungen der Process AI iOS-App.",
        h1: "Nutzungsbedingungen",
      },
      ko: {
        title: "이용약관 — Process AI",
        description: "Process AI iOS 앱 이용약관.",
        h1: "이용약관",
      },
      es: {
        title: "Condiciones de uso — Process AI",
        description: "Condiciones de uso de la app iOS Process AI.",
        h1: "Condiciones de uso",
      },
      "pt-BR": {
        title: "Termos de uso — Process AI",
        description: "Termos de uso do app iOS Process AI.",
        h1: "Termos de uso",
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
      ja: {
        title: "プライバシーポリシー — Process AI",
        description: "Process AI iOSアプリのプライバシーポリシー。",
        h1: "プライバシーポリシー",
      },
      de: {
        title: "Datenschutzerklärung — Process AI",
        description: "Datenschutzerklärung der Process AI iOS-App.",
        h1: "Datenschutzerklärung",
      },
      ko: {
        title: "개인정보 처리방침 — Process AI",
        description: "Process AI iOS 앱 개인정보 처리방침.",
        h1: "개인정보 처리방침",
      },
      es: {
        title: "Política de privacidad — Process AI",
        description: "Política de privacidad de la app iOS Process AI.",
        h1: "Política de privacidad",
      },
      "pt-BR": {
        title: "Política de privacidade — Process AI",
        description: "Política de privacidade do app iOS Process AI.",
        h1: "Política de privacidade",
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
      ja: {
        title: "法的表記 — Process AI",
        description: "useprocess.xyz と Process AI アプリの法的表記。",
        h1: "法的表記",
      },
      de: {
        title: "Impressum — Process AI",
        description: "Impressum von useprocess.xyz und der Process AI App.",
        h1: "Impressum",
      },
      ko: {
        title: "법적 고지 — Process AI",
        description: "useprocess.xyz 및 Process AI 앱 법적 고지.",
        h1: "법적 고지",
      },
      es: {
        title: "Aviso legal — Process AI",
        description: "Aviso legal de useprocess.xyz y la app Process AI.",
        h1: "Aviso legal",
      },
      "pt-BR": {
        title: "Aviso legal — Process AI",
        description: "Aviso legal de useprocess.xyz e do app Process AI.",
        h1: "Aviso legal",
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
      ja: {
        title: "サポート — Process AI",
        description: "iOSアプリ、サブスクリプション、データに関する Process AI サポート。",
        h1: "サポート",
      },
      de: {
        title: "Support — Process AI",
        description: "Process AI Support für die iOS-App, Abo oder deine Daten.",
        h1: "Support",
      },
      ko: {
        title: "지원 — Process AI",
        description: "iOS 앱, 구독, 데이터 관련 Process AI 지원.",
        h1: "지원",
      },
      es: {
        title: "Soporte — Process AI",
        description: "Contacta el soporte de Process AI para la app iOS, la suscripción o tus datos.",
        h1: "Soporte",
      },
      "pt-BR": {
        title: "Suporte — Process AI",
        description: "Fale com o suporte Process AI sobre o app iOS, a assinatura ou seus dados.",
        h1: "Suporte",
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
      ja: {
        title: "健康ソース — Process AI",
        description: "Process AI が引用する医学ソース（WHO、CDC、NIH、Appleヘルスケア）。",
        h1: "健康ソースと参考文献",
      },
      de: {
        title: "Gesundheitsquellen — Process AI",
        description: "Medizinische Quellen in Process AI (WHO, CDC, NIH, Apple Health).",
        h1: "Gesundheitsquellen und Referenzen",
      },
      ko: {
        title: "건강 출처 — Process AI",
        description: "Process AI가 인용하는 의학 출처(WHO, CDC, NIH, Apple 건강).",
        h1: "건강 출처 및 참고문헌",
      },
      es: {
        title: "Fuentes de salud — Process AI",
        description: "Fuentes médicas citadas en Process AI (OMS, CDC, NIH, Apple Health).",
        h1: "Fuentes y referencias de salud",
      },
      "pt-BR": {
        title: "Fontes de saúde — Process AI",
        description: "Fontes médicas citadas no Process AI (OMS, CDC, NIH, Apple Saúde).",
        h1: "Fontes e referências de saúde",
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

    var meta = page[lang] || page.en || page.fr;
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
