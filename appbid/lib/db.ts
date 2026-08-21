import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { redisClient } from "./redis";
import { MIN_BID_USD, centsToDollars } from "./format";
import { onlineCount } from "./presence";
import type { BoardPayload, Listing, ListingKind } from "./types";

const LAUNCHED_AT = Date.parse("2026-08-21T16:00:00.000Z");
const HOUR_MS = 60 * 60 * 1000;
const LEGACY_VISITOR_FLOOR = 1532;
const REDIS_KEY = "appmog:store";
const REDIS_LOCK = "appmog:lock";
const REDIS_VISITORS_SET = "appmog:unique-visitors";
const SEED_LISTING_KEY = "appstore:6753808143";
const SEED_BID_CENTS = 1400; // $14 opening bid
const SEED_LISTING: Omit<ListingRow, "createdAt" | "updatedAt"> = {
  id: "seed-process-debloat",
  listingKey: SEED_LISTING_KEY,
  url: "https://apps.apple.com/fr/app/process-debloat-ton-visage/id6753808143",
  title: "Process : Debloat ton visage",
  description:
    "Debloat your face with a daily scan and a personalized anti-bloat plan. Dégonfle ton visage avec un scan quotidien.",
  icon: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/d4/d5/9d/d4d59dd0-4e2a-0757-bb9e-b8fab1c9d0c2/AppIcon-0-0-1x_U007epad-0-1-sRGB-85-220.png/512x512bb.jpg",
  kind: "appstore",
  bidCents: SEED_BID_CENTS,
  clicks: 0,
};

type ListingRow = {
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
};

type Store = {
  listings: ListingRow[];
  activity: Array<{
    id: string;
    listingId: string;
    rank: number;
    bidCents: number;
    createdAt: number;
  }>;
  clickHours: Record<string, number>;
  visitors: number;
  visitorIds?: string[];
  launchedAt: number;
  processedSessions: string[];
};

function emptyStore(): Store {
  return {
    listings: [],
    activity: [],
    clickHours: {},
    visitors: 0,
    launchedAt: LAUNCHED_AT,
    processedSessions: [],
  };
}

function migrateStore(store: Store): void {
  if (!store.visitorIds) {
    store.visitorIds = [];
    if (store.visitors >= LEGACY_VISITOR_FLOOR) store.visitors = 0;
  }
  store.visitors = store.visitorIds.length;
}

function ensureSeedListing(store: Store): void {
  const now = Date.now();
  const existing = store.listings.find((row) => row.listingKey === SEED_LISTING_KEY);

  if (existing) {
    if (existing.bidCents < SEED_BID_CENTS) {
      existing.bidCents = SEED_BID_CENTS;
      existing.updatedAt = now;
    }
    if (!existing.icon && SEED_LISTING.icon) existing.icon = SEED_LISTING.icon;
    if (!existing.description && SEED_LISTING.description) existing.description = SEED_LISTING.description;
    return;
  }

  const row: ListingRow = {
    ...SEED_LISTING,
    createdAt: now,
    updatedAt: now,
  };
  store.listings.push(row);
  store.activity.unshift({
    id: "seed-process-activity",
    listingId: row.id,
    rank: 1,
    bidCents: row.bidCents,
    createdAt: now,
  });
}

async function seededStore(): Promise<Store> {
  const store = await readStore();
  migrateStore(store);
  const hasSeed = store.listings.some((row) => row.listingKey === SEED_LISTING_KEY);
  const seedTooLow = store.listings.some(
    (row) => row.listingKey === SEED_LISTING_KEY && row.bidCents < SEED_BID_CENTS,
  );
  if (hasSeed && !seedTooLow) return store;
  return withLock((locked) => {
    migrateStore(locked);
    ensureSeedListing(locked);
    return locked;
  });
}

function redisClientFromDb(): ReturnType<typeof redisClient> {
  return redisClient();
}

function filePath(): string {
  const dir = process.env.VERCEL ? "/tmp" : path.join(process.cwd(), "data");
  mkdirSync(dir, { recursive: true });
  return path.join(dir, "store.json");
}

async function readStore(): Promise<Store> {
  const redis = redisClientFromDb();
  if (redis) {
    const data = await redis.get<Store>(REDIS_KEY);
    const store = data ? { ...emptyStore(), ...data } : emptyStore();
    migrateStore(store);
    return store;
  }
  try {
    const store = { ...emptyStore(), ...JSON.parse(readFileSync(filePath(), "utf8")) };
    migrateStore(store);
    return store;
  } catch {
    return emptyStore();
  }
}

async function writeStore(store: Store): Promise<void> {
  const redis = redisClientFromDb();
  if (redis) {
    await redis.set(REDIS_KEY, store);
    return;
  }
  writeFileSync(filePath(), JSON.stringify(store));
}

async function withLock<T>(fn: (store: Store) => Promise<T> | T): Promise<T> {
  const redis = redisClientFromDb();
  if (redis) {
    for (let i = 0; i < 25; i += 1) {
      const ok = await redis.set(REDIS_LOCK, "1", { nx: true, ex: 8 });
      if (ok) {
        try {
          const store = await readStore();
          const result = await fn(store);
          await writeStore(store);
          return result;
        } finally {
          await redis.del(REDIS_LOCK);
        }
      }
      await new Promise((r) => setTimeout(r, 40 + i * 12));
    }
    throw new Error("STORE_BUSY");
  }
  const store = await readStore();
  const result = await fn(store);
  await writeStore(store);
  return result;
}

function sortedListings(store: Store): ListingRow[] {
  return [...store.listings].sort((a, b) => b.bidCents - a.bidCents || a.updatedAt - b.updatedAt);
}

export async function registerUniqueVisitor(vid: string): Promise<number> {
  const id = vid.slice(0, 80);
  if (!id) return getUniqueVisitorCount();

  const redis = redisClientFromDb();
  if (redis) {
    await redis.sadd(REDIS_VISITORS_SET, id);
    return redis.scard(REDIS_VISITORS_SET);
  }

  return withLock((store) => {
    migrateStore(store);
    if (!store.visitorIds!.includes(id)) {
      store.visitorIds!.push(id);
    }
    store.visitors = store.visitorIds!.length;
    return store.visitors;
  });
}

export async function getUniqueVisitorCount(): Promise<number> {
  const redis = redisClientFromDb();
  if (redis) return redis.scard(REDIS_VISITORS_SET);

  const store = await readStore();
  migrateStore(store);
  return store.visitorIds?.length ?? 0;
}

/** @deprecated use registerUniqueVisitor */
export async function incrementVisitors(): Promise<number> {
  return getUniqueVisitorCount();
}

export async function getVisitorCount(): Promise<number> {
  return getUniqueVisitorCount();
}

export async function getLaunchedAt(): Promise<number> {
  return (await readStore()).launchedAt;
}

export async function findListingByKey(key: string) {
  const row = (await seededStore()).listings.find((l) => l.listingKey === key);
  if (!row) return null;
  return {
    id: row.id,
    listing_key: row.listingKey,
    url: row.url,
    title: row.title,
    description: row.description,
    icon: row.icon,
    kind: row.kind,
    bid_cents: row.bidCents,
  };
}

export async function findListingById(id: string) {
  const row = (await readStore()).listings.find((l) => l.id === id);
  if (!row) return null;
  return { id: row.id, url: row.url };
}

export async function topBidCents(): Promise<number> {
  const listings = sortedListings(await seededStore());
  return listings[0]?.bidCents ?? 0;
}

export async function listingAtRank(rank: number) {
  const listings = sortedListings(await seededStore());
  const row = listings[Math.max(0, rank - 1)];
  if (!row) return null;
  return { bid_cents: row.bidCents };
}

export async function hasProcessedSession(sessionId: string): Promise<boolean> {
  return (await readStore()).processedSessions.includes(sessionId);
}

export async function applyPaidBid(input: {
  sessionId: string;
  listingKey: string;
  url: string;
  title: string;
  description: string;
  icon: string;
  kind: ListingKind;
  targetBidCents: number;
}): Promise<{ id: string; rank: number; bidCents: number; title: string }> {
  return withLock((store) => {
    ensureSeedListing(store);
    const bid = Math.max(input.targetBidCents, MIN_BID_USD * 100);
    const now = Date.now();
    let row = store.listings.find((l) => l.listingKey === input.listingKey);
    if (!store.processedSessions.includes(input.sessionId)) {
      if (row) {
        row.url = input.url;
        row.title = input.title;
        row.description = input.description;
        row.icon = input.icon;
        row.kind = input.kind;
        row.bidCents = bid;
        row.updatedAt = now;
      } else {
        row = {
          id: randomUUID(),
          listingKey: input.listingKey,
          url: input.url,
          title: input.title,
          description: input.description,
          icon: input.icon,
          kind: input.kind,
          bidCents: bid,
          clicks: 0,
          createdAt: now,
          updatedAt: now,
        };
        store.listings.push(row);
      }
      const saved = row;
      store.processedSessions = [input.sessionId, ...store.processedSessions].slice(0, 4000);
      const rank = sortedListings(store).findIndex((l) => l.id === saved.id) + 1;
      store.activity.unshift({
        id: randomUUID(),
        listingId: saved.id,
        rank,
        bidCents: bid,
        createdAt: now,
      });
      store.activity = store.activity.slice(0, 80);
    }
    const current = store.listings.find((l) => l.listingKey === input.listingKey);
    if (!current) {
      return { id: "", rank: 0, bidCents: bid, title: input.title };
    }
    const rank = sortedListings(store).findIndex((l) => l.id === current.id) + 1;
    return { id: current.id, rank, bidCents: current.bidCents, title: current.title };
  });
}

export async function trackClick(id: string): Promise<string | null> {
  return withLock((store) => {
    const row = store.listings.find((l) => l.id === id);
    if (!row) return null;
    row.clicks += 1;
    const hour = Math.floor(Date.now() / HOUR_MS);
    const key = `${id}:${hour}`;
    store.clickHours[key] = (store.clickHours[key] ?? 0) + 1;
    const cutoff = hour - 48;
    for (const k of Object.keys(store.clickHours)) {
      const h = Number(k.split(":")[1] ?? 0);
      if (h < cutoff) delete store.clickHours[k];
    }
    return row.url;
  });
}

export async function getBoard(): Promise<BoardPayload> {
  const store = await seededStore();
  const listings: Listing[] = sortedListings(store).map((row, index) => ({
    id: row.id,
    listingKey: row.listingKey,
    url: row.url,
    title: row.title,
    description: row.description,
    icon: row.icon,
    kind: row.kind,
    bidCents: row.bidCents,
    clicks: row.clicks,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    rank: index + 1,
  }));

  const top = listings[0]?.bidCents ?? 0;
  const revenue = listings.reduce((sum, l) => sum + l.bidCents, 0);
  const revision = listings.reduce((max, l) => Math.max(max, l.updatedAt, l.bidCents), 0) + listings.length;

  return {
    listings,
    visitors: await getUniqueVisitorCount(),
    online: await onlineCount(),
    launchedAt: store.launchedAt,
    claimOneEuros: top > 0 ? centsToDollars(top) + 1 : MIN_BID_USD,
    revenueEuros: centsToDollars(revenue),
    revision,
  };
}

export async function resolveClaimAmount(input: {
  listingKey: string;
  requestedEuros: number;
  targetRank?: number;
}): Promise<{ chargeCents: number; targetBidCents: number; currentBidCents: number }> {
  const store = await seededStore();
  const existing = store.listings.find((l) => l.listingKey === input.listingKey);
  const currentBidCents = existing?.bidCents ?? 0;
  let targetEuros = Math.round(input.requestedEuros);

  if (input.targetRank && input.targetRank >= 1) {
    const occupant = sortedListings(store)[input.targetRank - 1];
    if (occupant) targetEuros = centsToDollars(occupant.bidCents) + 1;
  }

  if (!Number.isFinite(targetEuros) || targetEuros < MIN_BID_USD) {
    throw new Error("MIN_BID");
  }

  const targetBidCents = targetEuros * 100;
  if (existing && targetBidCents <= currentBidCents) {
    throw new Error("RAISE_ONLY");
  }

  return { chargeCents: targetBidCents - currentBidCents, targetBidCents, currentBidCents };
}
