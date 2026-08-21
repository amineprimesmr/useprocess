import { displayNameFromUrl, type NormalizedTarget } from "./keys";
import type { ListingMeta } from "./types";

function firstLetter(title: string): string {
  const t = title.replace(/^@/, "").trim();
  return (t[0] ?? "A").toUpperCase();
}

export function fallbackMeta(target: NormalizedTarget): ListingMeta {
  return {
    title: displayNameFromUrl(target.url, target.kind),
    description: "",
    icon: "",
    kind: "appstore",
  };
}

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      "user-agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
      accept: "application/json",
    },
    signal: AbortSignal.timeout(4500),
    cache: "no-store",
  });
  if (!res.ok) return "";
  return res.text();
}

async function fromApple(appleId: string): Promise<Partial<ListingMeta>> {
  const json = await fetchText(`https://itunes.apple.com/lookup?id=${appleId}&country=fr`);
  if (!json) return {};
  try {
    const data = JSON.parse(json) as {
      results?: Array<{
        trackName?: string;
        artworkUrl512?: string;
        artworkUrl100?: string;
        description?: string;
      }>;
    };
    const app = data.results?.[0];
    if (!app) return {};
    return {
      title: app.trackName ?? "",
      description: (app.description ?? "").split("\n")[0]?.slice(0, 220) ?? "",
      icon: app.artworkUrl512 || app.artworkUrl100 || "",
      kind: "appstore",
    };
  } catch {
    return {};
  }
}

export async function resolveMeta(target: NormalizedTarget): Promise<ListingMeta> {
  const base = fallbackMeta(target);
  if (!target.appleId) return base;
  try {
    const apple = await fromApple(target.appleId);
    return {
      ...base,
      ...apple,
      title: apple.title || base.title,
      kind: "appstore",
    };
  } catch {
    return base;
  }
}

export function letterFallback(title: string): string {
  return firstLetter(title);
}
