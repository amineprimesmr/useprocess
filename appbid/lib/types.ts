export type ListingKind = "appstore" | "play" | "handle" | "web";

export type Listing = {
  id: string;
  listingKey: string;
  url: string;
  title: string;
  description: string;
  icon: string;
  kind: ListingKind;
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
};
