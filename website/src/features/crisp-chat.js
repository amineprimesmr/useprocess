import { getSiteLanguage } from "./app-copy.js";

function isValidWebsiteID(value) {
  const id = String(value || "").trim();
  return id.length >= 8 && !id.startsWith("YOUR_");
}

async function loadWebsiteID() {
  try {
    const response = await fetch("/crisp-website-id.json", { cache: "no-store" });
    if (!response.ok) return "";
    const data = await response.json();
    return String(data.websiteID || "").trim();
  } catch {
    return "";
  }
}

export async function mountCrispChat() {
  if (typeof window === "undefined" || window.$crisp) return;
  const websiteID = await loadWebsiteID();
  if (!isValidWebsiteID(websiteID)) return;

  window.$crisp = [];
  window.CRISP_WEBSITE_ID = websiteID;

  const crispLang = {
    fr: "fr",
    en: "en",
    ja: "ja",
    de: "de",
    ko: "ko",
    es: "es",
    "pt-BR": "pt",
  }[getSiteLanguage()] || "en";
  window.$crisp.push(["set", "session:segments", [["website"]]]);
  window.$crisp.push(["set", "session:data", [[["app_language", getSiteLanguage()]]]]);
  window.CRISP_RUNTIME_CONFIG = { locale: crispLang };

  const script = document.createElement("script");
  script.src = "https://client.crisp.chat/l.js";
  script.async = true;
  document.head.appendChild(script);
}
