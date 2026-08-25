const test = require("node:test");
const assert = require("node:assert/strict");
const {
  clipperMetric,
  normalizeClipperSort,
  rankClippers,
  toPublicClipper,
} = require("../lib/affiliateLeaderboardShared.js");

function clipper(overrides = {}) {
  return toPublicClipper({
    affiliateId: "a1",
    viewerAffiliateId: "me",
    displayName: "Alex",
    primaryCode: "ALEX",
    stats: {
      lifetimeCents: 12000,
      paidCount: 3,
      referredCount: 10,
      linkViews: 80,
      paywallCount: 12,
    },
    ...overrides,
  });
}

test("normalizeClipperSort falls back to earnings", () => {
  assert.equal(normalizeClipperSort("sales"), "sales");
  assert.equal(normalizeClipperSort("visits"), "visits");
  assert.equal(normalizeClipperSort("nope"), "earnings");
  assert.equal(normalizeClipperSort(""), "earnings");
});

test("toPublicClipper hides ids and falls back to code", () => {
  const row = toPublicClipper({
    affiliateId: "secret-id",
    viewerAffiliateId: "secret-id",
    displayName: "  ",
    primaryCode: "",
    codes: ["MANNY"],
    stats: { lifetimeCents: 150.9, paidCount: -2 },
  });
  assert.equal(row.displayName, "MANNY");
  assert.equal(row.code, "MANNY");
  assert.equal(row.isYou, true);
  assert.equal(row.stats.lifetimeCents, 151);
  assert.equal(row.stats.paidCount, 0);
  assert.equal("affiliateId" in row, false);
});

test("rankClippers orders by earnings then sales then name", () => {
  const ranked = rankClippers([
    clipper({ affiliateId: "c", displayName: "Cam", primaryCode: "CAM", stats: { lifetimeCents: 5000, paidCount: 9 } }),
    clipper({ affiliateId: "b", displayName: "Bea", primaryCode: "BEA", stats: { lifetimeCents: 9000, paidCount: 1 } }),
    clipper({ affiliateId: "a", displayName: "Ada", primaryCode: "ADA", stats: { lifetimeCents: 9000, paidCount: 4 } }),
  ]);
  assert.deepEqual(
    ranked.map((row) => [row.rank, row.displayName]),
    [
      [1, "Ada"],
      [2, "Bea"],
      [3, "Cam"],
    ]
  );
});

test("rankClippers can sort by installs", () => {
  const ranked = rankClippers(
    [
      clipper({ affiliateId: "low", displayName: "Low", stats: { lifetimeCents: 99000, referredCount: 1 } }),
      clipper({ affiliateId: "high", displayName: "High", stats: { lifetimeCents: 10, referredCount: 40 } }),
    ],
    "installs"
  );
  assert.equal(ranked[0].displayName, "High");
  assert.equal(clipperMetric(ranked[0].stats, "installs"), 40);
});

test("isYou survives ranking", () => {
  const ranked = rankClippers([
    clipper({ affiliateId: "me", viewerAffiliateId: "me", displayName: "Me", stats: { lifetimeCents: 100 } }),
    clipper({ affiliateId: "other", viewerAffiliateId: "me", displayName: "Other", stats: { lifetimeCents: 900 } }),
  ]);
  assert.equal(ranked[0].isYou, false);
  assert.equal(ranked[1].isYou, true);
  assert.equal(ranked[1].rank, 2);
});
