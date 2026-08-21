import type { ListingKind } from "./types";

export type NormalizedTarget = {
  key: string;
  url: string;
  kind: ListingKind;
  appleId?: string;
};

function trimInput(raw: string): string {
  return raw.trim().replace(/\s+/g, " ");
}

function stripWww(host: string): string {
  return host.replace(/^www\./i, "").toLowerCase();
}

export function normalizeTarget(raw: string): NormalizedTarget | null {
  const input = trimInput(raw);
  if (!input) return null;

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

  const apple = host.endsWith("apps.apple.com") || host === "itunes.apple.com";
  if (!apple) return null;

  const idMatch = path.match(/id(\d+)/i) || url.search.match(/id=(\d+)/i);
  if (!idMatch) return null;
  const appleId = idMatch[1];
  return {
    key: `appstore:${appleId}`,
    url: `https://apps.apple.com/app/id${appleId}`,
    kind: "appstore",
    appleId,
  };
}

export function displayNameFromUrl(url: string, kind: ListingKind): string {
  if (kind === "appstore") return "App Store";
  try {
    const u = new URL(url);
    return stripWww(u.hostname) + (u.pathname === "/" ? "" : u.pathname.replace(/\/+$/, ""));
  } catch {
    return url;
  }
}
