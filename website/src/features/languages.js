/** Langues produit du site — aligné sur ProcessLanguageCode. */
export const SITE_LANGUAGES = [
  { code: "fr", label: "FR", htmlLang: "fr" },
  { code: "en", label: "EN", htmlLang: "en-US" },
  { code: "ja", label: "JA", htmlLang: "ja" },
  { code: "de", label: "DE", htmlLang: "de" },
  { code: "ko", label: "KO", htmlLang: "ko" },
  { code: "es", label: "ES", htmlLang: "es" },
  { code: "pt-BR", label: "PT", htmlLang: "pt-BR" },
];

export const SITE_LANGUAGE_CODES = SITE_LANGUAGES.map((item) => item.code);

export const APP_STORE_STOREFRONT = {
  fr: "fr",
  en: "us",
  ja: "jp",
  de: "de",
  ko: "kr",
  es: "es",
  "pt-BR": "br",
};

export function normalizeSiteLanguage(raw) {
  const lower = String(raw || "")
    .toLowerCase()
    .replace(/_/g, "-");
  if (lower.startsWith("fr")) return "fr";
  if (lower.startsWith("ja")) return "ja";
  if (lower.startsWith("de")) return "de";
  if (lower.startsWith("ko")) return "ko";
  if (lower.startsWith("pt")) return "pt-BR";
  if (lower.startsWith("es")) return "es";
  if (lower.startsWith("en")) return "en";
  if (lower === "pt-br") return "pt-BR";
  return null;
}
