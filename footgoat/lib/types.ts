export type ListingKind = "wiki" | "transfermarkt" | "player";

export type Listing = {
  id: string;
  listingKey: string;
  url: string;
  title: string;
  description: string;
  icon: string;
  kind: ListingKind;
  owner: string;
  bidCents: number;
  clicks: number;
  createdAt: number;
  updatedAt: number;
  rank: number;
};

export type BoardPayload = {
  listings: Listing[];
  visitors: number;
  online: number;
  launchedAt: number;
  claimOneEuros: number;
  revenueEuros: number;
  /** Bumps whenever ranks/bids change — for live client sync. */
  revision: number;
};

export type ListingMeta = {
  title: string;
  description: string;
  icon: string;
  kind: ListingKind;
  canonicalKey?: string;
  canonicalUrl?: string;
};
