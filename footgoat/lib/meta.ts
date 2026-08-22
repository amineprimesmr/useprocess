import type { Locale } from "./copy";
import { displayNameFromUrl, type NormalizedTarget } from "./keys";
import { playerArtUrl } from "./player-art";
import type { ListingKind, ListingMeta } from "./types";

function firstLetter(title: string): string {
  const t = title.replace(/^@/, "").trim();
  return (t[0] ?? "A").toUpperCase();
}

const FOOTBALL_HINT =
  /footballer|football player|soccer player|association football|footballeur|joueur de football|midfielder|striker|winger|goalkeeper|defender|forward|attaquant|milieu de terrain|défenseur|gardien|ailier/;

export function fallbackMeta(target: NormalizedTarget): ListingMeta {
  const title = target.wikiTitle || target.query || displayNameFromUrl(target.url, target.kind);
  return {
    title,
    description: "",
    icon: "",
    kind: target.kind,
    canonicalKey: target.key,
    canonicalUrl: target.url,
  };
}

async function fetchJson<T>(url: string): Promise<T | null> {
  const res = await fetch(url, {
    headers: {
      "user-agent": "footgoat.lol/1.0 (player lookup; https://footgoat.lol)",
      accept: "application/json",
    },
    signal: AbortSignal.timeout(5000),
    cache: "no-store",
  });
  if (!res.ok) return null;
  return (await res.json()) as T;
}

type WikiSummary = {
  title?: string;
  description?: string;
  extract?: string;
  type?: string;
  lang?: string;
  content_urls?: { desktop?: { page?: string } };
  thumbnail?: { source?: string };
  originalimage?: { source?: string };
  titles?: { canonical?: string; normalized?: string };
};

function looksLikeFootballer(summary: WikiSummary): boolean {
  const blob = `${summary.description ?? ""} ${summary.extract ?? ""}`.toLowerCase();
  return FOOTBALL_HINT.test(blob);
}

function metaFromSummary(summary: WikiSummary, fallbackKind: ListingKind): ListingMeta | null {
  const title = summary.title?.trim();
  if (!title) return null;
  if (summary.type === "disambiguation") return null;
  if (!looksLikeFootballer(summary)) return null;
  const page = summary.content_urls?.desktop?.page;
  const icon = summary.originalimage?.source || summary.thumbnail?.source || "";
  const description = (summary.description || summary.extract || "").split("\n")[0]?.slice(0, 220) ?? "";
  return {
    title,
    description,
    icon,
    kind: fallbackKind === "transfermarkt" ? "transfermarkt" : "wiki",
    canonicalKey: `wiki:${title.replace(/\s+/g, "_")}`,
    canonicalUrl: page || `https://en.wikipedia.org/wiki/${encodeURIComponent(title.replace(/\s+/g, "_"))}`,
  };
}

async function wikiSummary(title: string, locale: Locale): Promise<WikiSummary | null> {
  const langs = locale === "fr" ? ["fr", "en"] : ["en", "fr"];
  for (const lang of langs) {
    const slug = encodeURIComponent(title.replace(/\s+/g, "_"));
    const data = await fetchJson<WikiSummary>(`https://${lang}.wikipedia.org/api/rest_v1/page/summary/${slug}`);
    if (data?.title) return data;
  }
  return null;
}

async function wikiSearch(query: string, locale: Locale): Promise<string | null> {
  const langs = locale === "fr" ? ["fr", "en"] : ["en", "fr"];
  for (const lang of langs) {
    const q = encodeURIComponent(`${query} footballer`);
    const data = await fetchJson<[string, string[]]>(
      `https://${lang}.wikipedia.org/w/api.php?action=opensearch&search=${q}&limit=1&namespace=0&format=json&origin=*`,
    );
    const hit = data?.[1]?.[0];
    if (hit) return hit;
  }
  return null;
}

export async function resolveMeta(target: NormalizedTarget, locale: Locale = "fr"): Promise<ListingMeta> {
  const base = fallbackMeta(target);
  const query = target.wikiTitle || target.query || "";
  try {
    let summary = query ? await wikiSummary(query, locale) : null;
    if (!summary && query) {
      const hit = await wikiSearch(query, locale);
      if (hit) summary = await wikiSummary(hit, locale);
    }
    if (summary) {
      const parsed = metaFromSummary(summary, target.kind);
      if (parsed) {
        if (target.kind === "transfermarkt") {
          parsed.kind = "transfermarkt";
          parsed.canonicalKey = target.key;
          parsed.canonicalUrl = target.url;
        }
        const art = playerArtUrl(parsed.canonicalKey, parsed.title, target.key, query);
        return { ...base, ...parsed, title: parsed.title || base.title, icon: art || parsed.icon };
      }
    }
    const art = playerArtUrl(target.key, query, base.title);
    return art ? { ...base, icon: art } : base;
  } catch {
    return base;
  }
}

export function letterFallback(title: string): string {
  return firstLetter(title);
}
