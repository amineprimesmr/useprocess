import { centsToDollars } from "./format";
import type { Listing } from "./types";

export type BidQuote = {
  listingKey: string | null;
  currentEuros: number;
  targetEuros: number;
  chargeEuros: number;
  projectedRank: number;
  isExisting: boolean;
  canRaise: boolean;
};

export function projectedRank(listings: Listing[], listingKey: string | null, targetBidCents: number): number {
  let rank = 1;
  for (const listing of listings) {
    if (listingKey && listing.listingKey === listingKey) continue;
    if (listing.bidCents >= targetBidCents) rank += 1;
  }
  return rank;
}

export function quoteBid(input: {
  listings: Listing[];
  listingKey: string | null;
  targetEuros: number;
  minTargetEuros: number;
}): BidQuote {
  const targetEuros = Math.max(Math.round(input.targetEuros), input.minTargetEuros);
  const existing = input.listingKey
    ? input.listings.find((listing) => listing.listingKey === input.listingKey) ?? null
    : null;
  const currentEuros = existing ? centsToDollars(existing.bidCents) : 0;
  const targetBidCents = targetEuros * 100;
  const chargeEuros = targetEuros;

  return {
    listingKey: input.listingKey,
    currentEuros,
    targetEuros,
    chargeEuros,
    projectedRank: projectedRank(input.listings, input.listingKey, targetBidCents),
    isExisting: Boolean(existing),
    canRaise: !existing || targetEuros > currentEuros,
  };
}
