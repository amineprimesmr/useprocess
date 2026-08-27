import { createHash } from "node:crypto";

const BOT_UA =
  /\b(bot|crawler|spider|crawling|preview|facebookexternalhit|facebot|twitterbot|slackbot|telegrambot|whatsapp|linkedinbot|googlebot|bingbot|applebot|duckduckbot|yandexbot|baiduspider|bytespider|gptbot|chatgpt|claudebot|meta-externalagent|pingdom|uptimerobot)\b/i;

const MOBILE_UA = /\b(iphone|ipad|ipod|android|mobile|tiktok|musical_ly)\b/i;

export function utcDayKey(date = new Date()): string {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function utcHourKey(date = new Date()): string {
  return `${utcDayKey(date)}T${String(date.getUTCHours()).padStart(2, "0")}`;
}

export function lastNDayKeys(days: number, from = new Date()): string[] {
  const count = Math.max(1, Math.min(90, Math.floor(days)));
  const keys: string[] = [];
  const start = Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate());
  for (let i = count - 1; i >= 0; i -= 1) {
    keys.push(utcDayKey(new Date(start - i * 86_400_000)));
  }
  return keys;
}

export function hashKey(raw: string): string {
  return createHash("sha256").update(String(raw || "")).digest("hex").slice(0, 24);
}

export function sanitizeVisitorId(raw: unknown): string {
  return String(raw || "")
    .trim()
    .replace(/[^A-Za-z0-9_-]/g, "")
    .slice(0, 64);
}

export function isLikelyBotUserAgent(userAgent: string): boolean {
  const ua = String(userAgent || "").trim();
  if (!ua) return false;
  if (MOBILE_UA.test(ua)) return false;
  return BOT_UA.test(ua);
}

export type AffiliateDailyCounts = {
  linkViews: number;
  storeClicks: number;
  attributions: number;
  paywalls: number;
  /** Free trials started — the clipper's work lands here days before any money does. */
  trials: number;
  /** Trials that turned into a paid subscription. */
  trialConversions: number;
  sales: number;
  earningsCents: number;
};

export const EMPTY_DAILY_COUNTS: AffiliateDailyCounts = {
  linkViews: 0,
  storeClicks: 0,
  attributions: 0,
  paywalls: 0,
  trials: 0,
  trialConversions: 0,
  sales: 0,
  earningsCents: 0,
};

export function emptyDailySeries(days: number): {
  days: string[];
  linkViews: number[];
  storeClicks: number[];
  attributions: number[];
  paywalls: number[];
  trials: number[];
  trialConversions: number[];
  sales: number[];
  earningsCents: number[];
} {
  const keys = lastNDayKeys(days);
  const zeros = keys.map(() => 0);
  return {
    days: keys,
    linkViews: [...zeros],
    storeClicks: [...zeros],
    attributions: [...zeros],
    paywalls: [...zeros],
    trials: [...zeros],
    trialConversions: [...zeros],
    sales: [...zeros],
    earningsCents: [...zeros],
  };
}
