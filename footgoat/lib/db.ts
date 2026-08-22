import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { redisClient } from "./redis";
import { MAX_BID_USD, MIN_BID_USD, centsToDollars } from "./format";
import { onlineCount } from "./presence";
import { applyPlayerArt } from "./player-art";
import type { BoardPayload, Listing, ListingKind } from "./types";

const LAUNCHED_AT = Date.parse("2026-08-22T00:00:00.000Z");
const HOUR_MS = 60 * 60 * 1000;
const LEGACY_VISITOR_FLOOR = 0;
const REDIS_KEY = "footgoat:store";
const REDIS_LOCK = "footgoat:lock";
const REDIS_VISITORS_SET = "footgoat:unique-visitors";
const SEED_PLAYERS: Array<Omit<ListingRow, "createdAt" | "updatedAt" | "owner" | "clicks"> & { clicks?: number }> = [
  { id: "seed-lionel-messi", listingKey: "wiki:Lionel_Messi", url: "https://en.wikipedia.org/wiki/Lionel_Messi", title: "Lionel Messi", description: "Argentine footballer (born 1987)", icon: "/players/messi.jpg", kind: "wiki", bidCents: 2100 },
  { id: "seed-cristiano-ronaldo", listingKey: "wiki:Cristiano_Ronaldo", url: "https://en.wikipedia.org/wiki/Cristiano_Ronaldo", title: "Cristiano Ronaldo", description: "Portuguese footballer (born 1985)", icon: "/players/ronaldo.jpg", kind: "wiki", bidCents: 2000 },
  { id: "seed-pele", listingKey: "wiki:Pelé", url: "https://en.wikipedia.org/wiki/Pelé", title: "Pelé", description: "Brazilian footballer (1940–2022)", icon: "/players/pele.jpg", kind: "wiki", bidCents: 1900 },
  { id: "seed-diego-maradona", listingKey: "wiki:Diego_Maradona", url: "https://en.wikipedia.org/wiki/Diego_Maradona", title: "Diego Maradona", description: "Argentine footballer (1960–2020)", icon: "/players/maradona.jpg", kind: "wiki", bidCents: 1800 },
  { id: "seed-zinedine-zidane", listingKey: "wiki:Zinedine_Zidane", url: "https://en.wikipedia.org/wiki/Zinedine_Zidane", title: "Zinedine Zidane", description: "French footballer (born 1972)", icon: "/players/zidane.jpg", kind: "wiki", bidCents: 1700 },
  { id: "seed-r9", listingKey: "wiki:Ronaldo_(Brazilian_footballer)", url: "https://en.wikipedia.org/wiki/Ronaldo_(Brazilian_footballer)", title: "Ronaldo Nazário", description: "Brazilian footballer (born 1976)", icon: "/players/r9.jpg", kind: "wiki", bidCents: 1600 },
  { id: "seed-johan-cruyff", listingKey: "wiki:Johan_Cruyff", url: "https://en.wikipedia.org/wiki/Johan_Cruyff", title: "Johan Cruyff", description: "Dutch footballer (1947–2016)", icon: "/players/cruyff.jpg", kind: "wiki", bidCents: 1500 },
  { id: "seed-ronaldinho", listingKey: "wiki:Ronaldinho", url: "https://en.wikipedia.org/wiki/Ronaldinho", title: "Ronaldinho", description: "Brazilian footballer (born 1980)", icon: "/players/ronaldinho.jpg", kind: "wiki", bidCents: 1400 },
  { id: "seed-kylian-mbappe", listingKey: "wiki:Kylian_Mbappé", url: "https://en.wikipedia.org/wiki/Kylian_Mbappé", title: "Kylian Mbappé", description: "French footballer (born 1998)", icon: "/players/mbappe.jpg", kind: "wiki", bidCents: 1300 },
  { id: "seed-neymar", listingKey: "wiki:Neymar", url: "https://en.wikipedia.org/wiki/Neymar", title: "Neymar", description: "Brazilian footballer (born 1992)", icon: "/players/neymar.jpg", kind: "wiki", bidCents: 1200 },
  { id: "seed-zlatan", listingKey: "wiki:Zlatan_Ibrahimović", url: "https://en.wikipedia.org/wiki/Zlatan_Ibrahimović", title: "Zlatan Ibrahimović", description: "Swedish footballer (born 1981)", icon: "/players/zlatan.jpg", kind: "wiki", bidCents: 1100 },
  { id: "seed-karim-benzema", listingKey: "wiki:Karim_Benzema", url: "https://en.wikipedia.org/wiki/Karim_Benzema", title: "Karim Benzema", description: "French footballer (born 1987)", icon: "/players/benzema.jpg", kind: "wiki", bidCents: 1000 },
  { id: "seed-erling-haaland", listingKey: "wiki:Erling_Haaland", url: "https://en.wikipedia.org/wiki/Erling_Haaland", title: "Erling Haaland", description: "Norwegian footballer (born 2000)", icon: "/players/haaland.jpg", kind: "wiki", bidCents: 900 },
  { id: "seed-virgil-van-dijk", listingKey: "wiki:Virgil_van_Dijk", url: "https://en.wikipedia.org/wiki/Virgil_van_Dijk", title: "Virgil van Dijk", description: "Dutch footballer (born 1991)", icon: "/players/vandijk.jpg", kind: "wiki", bidCents: 850 },
  { id: "seed-gareth-bale", listingKey: "wiki:Gareth_Bale", url: "https://en.wikipedia.org/wiki/Gareth_Bale", title: "Gareth Bale", description: "Welsh footballer (born 1989)", icon: "/players/bale.jpg", kind: "wiki", bidCents: 800 },
  { id: "seed-toni-kroos", listingKey: "wiki:Toni_Kroos", url: "https://en.wikipedia.org/wiki/Toni_Kroos", title: "Toni Kroos", description: "German footballer (born 1990)", icon: "/players/kroos.jpg", kind: "wiki", bidCents: 750 },
  { id: "seed-vinicius", listingKey: "wiki:Vinícius_Júnior", url: "https://en.wikipedia.org/wiki/Vinícius_Júnior", title: "Vinícius Júnior", description: "Brazilian footballer (born 2000)", icon: "/players/vinicius.jpg", kind: "wiki", bidCents: 700 },
  { id: "seed-jude-bellingham", listingKey: "wiki:Jude_Bellingham", url: "https://en.wikipedia.org/wiki/Jude_Bellingham", title: "Jude Bellingham", description: "English footballer (born 2003)", icon: "/players/bellingham.jpg", kind: "wiki", bidCents: 650 },
  { id: "seed-lamine-yamal", listingKey: "wiki:Lamine_Yamal", url: "https://en.wikipedia.org/wiki/Lamine_Yamal", title: "Lamine Yamal", description: "Spanish footballer (born 2007)", icon: "/players/yamal.jpg", kind: "wiki", bidCents: 600 },
];

type ListingRow = {
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
  for (const row of store.listings) {
    if (typeof row.owner !== "string") row.owner = "";
  }
}

function ensureSeedListing(store: Store): void {
  const now = Date.now();
  for (const seed of SEED_PLAYERS) {
    const existing = store.listings.find((row) => row.listingKey === seed.listingKey);
    if (existing) {
      if (!existing.owner) {
        existing.owner = "";
        existing.bidCents = seed.bidCents;
        existing.title = seed.title;
        existing.description = seed.description;
        existing.icon = seed.icon;
        existing.url = seed.url;
      } else if (existing.icon !== seed.icon) {
        existing.icon = seed.icon;
      }
      continue;
    }
    const row: ListingRow = {
      ...seed,
      owner: "",
      clicks: 0,
      createdAt: now,
      updatedAt: now,
    };
    store.listings.push(row);
    store.activity.unshift({
      id: `${seed.id}-activity`,
      listingId: row.id,
      rank: 0,
      bidCents: row.bidCents,
      createdAt: now,
    });
  }
}

async function seededStore(): Promise<Store> {
  const store = await readStore();
  migrateStore(store);
  const missing = SEED_PLAYERS.some((seed) => !store.listings.some((row) => row.listingKey === seed.listingKey));
  if (!missing) return store;
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
    owner: row.owner,
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
  owner: string;
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
        row.owner = input.owner;
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
          owner: input.owner,
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
  const listings: Listing[] = sortedListings(store).map((row, index) => applyPlayerArt({
    id: row.id,
    listingKey: row.listingKey,
    url: row.url,
    title: row.title,
    description: row.description,
    icon: row.icon,
    kind: row.kind,
    owner: row.owner ?? "",
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
  if (targetEuros > MAX_BID_USD) {
    throw new Error("MAX_BID");
  }

  const targetBidCents = targetEuros * 100;
  if (existing && targetBidCents <= currentBidCents) {
    throw new Error("RAISE_ONLY");
  }

  return { chargeCents: targetBidCents, targetBidCents, currentBidCents };
}
