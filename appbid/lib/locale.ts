import { prefersEnglishFromHeader } from "./format";
import type { Locale } from "./copy";

export const LOCALE_COOKIE = "appmog.locale";

const FR_COUNTRIES = new Set(["FR", "BE", "CH", "LU", "MC", "SN", "CI", "MA", "TN", "DZ"]);
const EN_COUNTRIES = new Set(["US", "GB", "CA", "AU", "NZ", "IE", "SG", "IN", "PH", "ZA"]);

const US_TIMEZONES = new Set([
  "America/New_York",
  "America/Detroit",
  "America/Kentucky/Louisville",
  "America/Kentucky/Monticello",
  "America/Indiana/Indianapolis",
  "America/Indiana/Vincennes",
  "America/Indiana/Winamac",
  "America/Indiana/Marengo",
  "America/Indiana/Petersburg",
  "America/Indiana/Tell_City",
  "America/Indiana/Knox",
  "America/Indiana/Vevay",
  "America/Chicago",
  "America/Menominee",
  "America/North_Dakota/Center",
  "America/North_Dakota/New_Salem",
  "America/North_Dakota/Beulah",
  "America/Denver",
  "America/Boise",
  "America/Phoenix",
  "America/Los_Angeles",
  "America/Anchorage",
  "America/Juneau",
  "America/Sitka",
  "America/Metlakatla",
  "America/Yakutat",
  "America/Nome",
  "America/Adak",
  "Pacific/Honolulu",
]);

export function resolveLocale(country: string | null | undefined, acceptLanguage: string | null | undefined): Locale {
  const code = (country ?? "").toUpperCase();
  if (code === "US") return "en";
  if (FR_COUNTRIES.has(code)) return "fr";
  if (EN_COUNTRIES.has(code)) return "en";
  if (prefersEnglishFromHeader(acceptLanguage ?? null)) return "en";
  return "fr";
}

export function detectClientLocale(fallback: Locale = "fr"): Locale {
  if (typeof document !== "undefined") {
    const match = document.cookie.match(new RegExp(`(?:^|;\\s*)${LOCALE_COOKIE}=(en|fr)(?:;|$)`));
    if (match?.[1] === "en" || match?.[1] === "fr") return match[1];
  }

  if (typeof navigator !== "undefined") {
    const langs = navigator.languages?.length ? navigator.languages : [navigator.language];
    for (const lang of langs) {
      const l = lang.toLowerCase();
      if (l.startsWith("fr")) return "fr";
      if (l.startsWith("en")) return "en";
    }
  }

  try {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (US_TIMEZONES.has(tz)) return "en";
  } catch {
    /* ignore */
  }

  return fallback;
}

export function localeHtmlLang(locale: Locale): string {
  return locale === "en" ? "en-US" : "fr-FR";
}

export function localeItunesCountry(locale: Locale): string {
  return locale === "en" ? "us" : "fr";
}
