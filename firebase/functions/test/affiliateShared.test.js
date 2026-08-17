const test = require("node:test");
const assert = require("node:assert/strict");
const {
  commissionFromRevenueCatEvent,
  normalizeAffiliateCode,
} = require("../lib/affiliateShared.js");

test("normalize affiliate vanity codes", () => {
  assert.equal(normalizeAffiliateCode("  manny  "), "MANNY");
  assert.equal(normalizeAffiliateCode("toji-bloat"), "TOJI-BLOAT");
});

test("40% commission on net after store cut", () => {
  const result = commissionFromRevenueCatEvent({
    product_id: "com.useprocess.monthly999",
    price: 24.99,
    currency: "EUR",
  });
  assert.ok(result);
  assert.equal(result.grossCents, 2499);
  assert.equal(result.netCents, Math.round(2499 * 0.7));
  assert.equal(result.commissionCents, Math.round(result.netCents * 0.4));
});

test("lifetime purchases are excluded", () => {
  const result = commissionFromRevenueCatEvent({
    product_id: "com.useprocess.lifetime",
    price: 19.99,
    currency: "EUR",
  });
  assert.equal(result, null);
});
