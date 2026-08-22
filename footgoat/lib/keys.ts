import type { ListingKind } from "./types";

export type NormalizedTarget = {
  key: string;
  url: string;
  kind: ListingKind;
  wikiTitle?: string;
  transfermarktId?: string;
  query?: string;
};

function trimInput(raw: string): string {
  return raw.trim().replace(/\s+/g, " ");
}

function stripWww(host: string): string {
  return host.replace(/^www\./i, "").toLowerCase();
}

function titleFromSlug(slug: string): string {
  return decodeURIComponent(slug.replace(/_/g, " ")).trim();
}

function wikiKey(title: string): string {
  return `wiki:${title.trim().replace(/\s+/g, "_")}`;
}

function wikiUrl(title: string, lang = "en"): string {
  const slug = title.trim().replace(/\s+/g, "_");
  return `https://${lang}.wikipedia.org/wiki/${encodeURIComponent(slug).replace(/%2F/gi, "/")}`;
}

function isPlayerName(input: string): boolean {
  if (input.length < 2 || input.length > 80) return false;
  if (/https?:\/\//i.test(input) || input.includes(".")) return false;
  return /^[\p{L}][\p{L}\p{M}\s.'’-]*[\p{L}]$/u.test(input) || /^[\p{L}]{2,}$/u.test(input);
}

export function normalizeTarget(raw: string): NormalizedTarget | null {
  const input = trimInput(raw);
  if (!input) return null;

  if (isPlayerName(input)) {
    const title = input;
    return {
      key: wikiKey(title),
      url: wikiUrl(title),
      kind: "player",
      wikiTitle: title,
      query: title,
    };
  }

  let urlText = input;
  if (!/^https?:\/\//i.test(urlText)) urlText = `https://${urlText}`;

  let url: URL;
  try {
    url = new URL(urlText);
  } catch {
    return null;
  }

  if (url.protocol !== "http:" && url.protocol !== "https:") return null;
  const host = stripWww(url.hostname);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  const wikiLang = host.match(/^([a-z]{2,3})\.wikipedia\.org$/i);
  if (wikiLang && path.startsWith("/wiki/")) {
    const slug = decodeURIComponent(path.slice("/wiki/".length));
    if (!slug || slug.includes(":")) return null;
    const title = titleFromSlug(slug);
    if (!title) return null;
    return {
      key: wikiKey(title),
      url: wikiUrl(title, wikiLang[1].toLowerCase()),
      kind: "wiki",
      wikiTitle: title,
    };
  }

  if (host.includes("transfermarkt.")) {
    const match = path.match(/\/spieler\/(\d+)/i) || path.match(/\/player\/(\d+)/i);
    if (!match) return null;
    const id = match[1];
    const slug = path.split("/").filter(Boolean)[0] ?? `player-${id}`;
    return {
      key: `tm:${id}`,
      url: `https://www.transfermarkt.com/${slug}/profil/spieler/${id}`,
      kind: "transfermarkt",
      transfermarktId: id,
      query: titleFromSlug(slug.replace(/-/g, " ")),
    };
  }

  return null;
}

export function displayNameFromUrl(url: string, kind: ListingKind): string {
  if (kind === "transfermarkt") return "Transfermarkt";
  if (kind === "wiki" || kind === "player") return "Wikipedia";
  try {
    const u = new URL(url);
    return stripWww(u.hostname) + (u.pathname === "/" ? "" : u.pathname.replace(/\/+$/, ""));
  } catch {
    return url;
  }
}
