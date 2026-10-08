const test = require("node:test");
const assert = require("node:assert");
const { mergeSubscribers, hasActivePremium, hasPaidPremium } = require("../lib/revenueCat");

const future = new Date(Date.now() + 86400000 * 30).toISOString();
const past = new Date(Date.now() - 86400000).toISOString();

test("MoneyMaker purchase unlocks premium when RevenueCat has expired", () => {
  const rc = { subscriber: { entitlements: { premium: { expires_date: past, product_identifier: "com.useprocess.monthly999" } }, subscriptions: { "com.useprocess.monthly999": { period_type: "normal" } }, non_subscriptions: {} } };
  const mm = { subscriber: { entitlements: { premium: { expires_date: future, product_identifier: "com.useprocess.annual3499" } }, subscriptions: { "com.useprocess.annual3499": { period_type: "normal" } }, non_subscriptions: {} } };
  const merged = mergeSubscribers(rc, mm);
  assert.equal(hasActivePremium(merged, "premium"), true);
  assert.equal(hasPaidPremium(merged, "premium"), true);
  assert.equal(hasActivePremium(mergeSubscribers(rc, null), "premium"), false);
});

test("lifetime (no expiry) always wins and missing sides are tolerated", () => {
  const life = { subscriber: { entitlements: { premium: { expires_date: null, product_identifier: "com.useprocess.lifetime" } }, subscriptions: {}, non_subscriptions: { "com.useprocess.lifetime": [{ id: "1" }] } } };
  const sub = { subscriber: { entitlements: { premium: { expires_date: future, product_identifier: "x" } }, subscriptions: {}, non_subscriptions: {} } };
  assert.equal(mergeSubscribers(sub, life).subscriber.entitlements.premium.product_identifier, "com.useprocess.lifetime");
  assert.equal(mergeSubscribers(null, sub), sub);
});
