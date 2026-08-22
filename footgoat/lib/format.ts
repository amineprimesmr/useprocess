export const MIN_BID_USD = 5;
/** Stripe Checkout unit_amount max is $999,999.99. */
export const MAX_BID_USD = 999_999;
/** @deprecated use MIN_BID_USD */
export const MIN_BID_EUROS = MIN_BID_USD;

export function parseBidInput(raw: string, min = MIN_BID_USD, max = MAX_BID_USD): number {
  const cleaned = raw.trim().toLowerCase().replace(/[\s$,€]/g, "");
  if (!cleaned) return min;
  const suffix = cleaned.endsWith("k") ? "k" : cleaned.endsWith("m") ? "m" : "";
  const digits = suffix ? cleaned.slice(0, -1) : cleaned;
  const num = Number(digits.replace(",", "."));
  if (!Number.isFinite(num) || num <= 0) return min;
  const dollars = Math.round(suffix === "k" ? num * 1_000 : suffix === "m" ? num * 1_000_000 : num);
  return Math.min(max, Math.max(min, dollars));
}

export function dollarsToCents(dollars: number): number {
  return Math.round(dollars) * 100;
}

export function centsToDollars(cents: number): number {
  return Math.round(cents / 100);
}

/** @deprecated use centsToDollars */
export const centsToEuros = centsToDollars;

/** @deprecated use dollarsToCents */
export const eurosToCents = dollarsToCents;

export function formatMoney(dollars: number, locale: "fr" | "en"): string {
  const n = Math.max(0, Math.round(dollars));
  if (locale === "fr") {
    return `${n.toLocaleString("fr-FR")} $`;
  }
  return `$${n.toLocaleString("en-US")}`;
}

/** @deprecated use formatMoney */
export const formatEuros = formatMoney;

export function formatCompactCount(n: number, locale: "fr" | "en"): string {
  return n.toLocaleString(locale === "fr" ? "fr-FR" : "en-US");
}

export function relativeTime(ts: number, locale: "fr" | "en", now = Date.now()): string {
  const seconds = Math.max(0, Math.round((now - ts) / 1000));
  if (seconds < 10) return locale === "fr" ? "à l'instant" : "just now";
  if (seconds < 60) {
    return locale === "fr" ? `il y a ${seconds} s` : `${seconds}s ago`;
  }
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) {
    if (locale === "fr") return minutes <= 1 ? "il y a 1 minute" : `il y a ${minutes} minutes`;
    return minutes <= 1 ? "1 minute ago" : `${minutes} minutes ago`;
  }
  const hours = Math.round(minutes / 60);
  if (hours < 24) {
    if (locale === "fr") return hours <= 1 ? "il y a 1 heure" : `il y a ${hours} heures`;
    return hours <= 1 ? "1 hour ago" : `${hours} hours ago`;
  }
  const days = Math.round(hours / 24);
  if (locale === "fr") return days <= 1 ? "hier" : `il y a ${days} jours`;
  return days <= 1 ? "yesterday" : `${days} days ago`;
}

export function hueFromKey(key: string): number {
  let h = 0;
  for (let i = 0; i < key.length; i += 1) {
    h = (h * 33 + key.charCodeAt(i)) % 360;
  }
  return h;
}

export function prefersEnglishFromHeader(header: string | null): boolean {
  const raw = (header ?? "").toLowerCase();
  if (!raw) return false;
  const parts = raw.split(",").map((p) => p.trim().split(";")[0]);
  for (const part of parts) {
    if (part.startsWith("fr")) return false;
    if (part.startsWith("en")) return true;
  }
  return false;
}

export function prefersEnglishFromNavigator(): boolean {
  if (typeof navigator === "undefined") return false;
  const langs = navigator.languages?.length ? navigator.languages : [navigator.language];
  for (const lang of langs) {
    const l = lang.toLowerCase();
    if (l.startsWith("fr")) return false;
    if (l.startsWith("en")) return true;
  }
  return false;
}
