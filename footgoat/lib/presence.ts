import { redisClient } from "./redis";

type Heartbeat = { lastSeen: number };

const WINDOW_MS = 90_000;
const PRESENCE_KEY = "footgoat:presence";

const visitors = new Map<string, Heartbeat>();

function liveCountMemory(): number {
  const now = Date.now();
  let n = 0;
  for (const value of visitors.values()) {
    if (now - value.lastSeen <= WINDOW_MS) n += 1;
  }
  return n;
}

function pingPresenceMemory(id: string): number {
  const now = Date.now();
  visitors.set(id, { lastSeen: now });
  for (const [key, value] of visitors) {
    if (now - value.lastSeen > WINDOW_MS) visitors.delete(key);
  }
  return liveCountMemory();
}

export async function pingPresence(id: string): Promise<number> {
  const redis = redisClient();
  if (!redis) return pingPresenceMemory(id);

  const now = Date.now();
  await redis.zadd(PRESENCE_KEY, { score: now, member: id.slice(0, 80) });
  await redis.zremrangebyscore(PRESENCE_KEY, 0, now - WINDOW_MS);
  return redis.zcard(PRESENCE_KEY);
}

export async function onlineCount(): Promise<number> {
  const redis = redisClient();
  if (!redis) return liveCountMemory();

  const now = Date.now();
  await redis.zremrangebyscore(PRESENCE_KEY, 0, now - WINDOW_MS);
  return redis.zcard(PRESENCE_KEY);
}
