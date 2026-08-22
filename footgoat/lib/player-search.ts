import { normalizePlayerName, playerArtUrl } from "@/lib/player-art";
import type { Listing } from "@/lib/types";

export type PlayerHit = {
  listing: Listing;
  score: number;
};

export function searchPlayers(listings: Listing[], query: string): PlayerHit[] {
  const q = normalizePlayerName(query);
  if (!q) {
    return listings.slice(0, 8).map((listing) => ({ listing, score: 1 }));
  }

  const art = playerArtUrl(q);
  const hits: PlayerHit[] = [];

  for (const listing of listings) {
    const title = normalizePlayerName(listing.title);
    const listingArt = playerArtUrl(listing.listingKey, listing.title);
    let score = 0;

    if (title === q) score = 100;
    else if (title.startsWith(q) || title.split(" ").some((part) => part.startsWith(q))) score = 80;
    else if (title.includes(q)) score = 60;
    else if (q.length >= 3 && q.includes(title)) score = 50;

    if (art && listingArt && art === listingArt) {
      score = Math.max(score, title === q ? 100 : 90);
    }

    if (score > 0) hits.push({ listing, score });
  }

  return hits.sort((a, b) => b.score - a.score || a.listing.rank - b.listing.rank);
}

export function matchPlayer(listings: Listing[], query: string): Listing | null {
  const q = normalizePlayerName(query);
  if (!q) return null;

  const hits = searchPlayers(listings, query);
  if (!hits.length) return null;

  const exact = hits.find((hit) => normalizePlayerName(hit.listing.title) === q);
  if (exact) return exact.listing;

  if (hits[0].score >= 90 && (hits.length === 1 || hits[0].score > hits[1].score)) {
    return hits[0].listing;
  }

  return null;
}
