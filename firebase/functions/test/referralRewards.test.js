const test = require("node:test");
const assert = require("node:assert/strict");
const {
  hasPaidPremium,
  isAnnualProduct,
  isPaidPurchaseEvent,
} = require("../lib/revenueCat.js");

test("trial webhook events are not paid", () => {
  assert.equal(isPaidPurchaseEvent({ period_type: "TRIAL", price: 0 }), false);
  assert.equal(isPaidPurchaseEvent({ period_type: "PROMOTIONAL" }), false);
});

test("paid initial purchase and trial conversion are paid", () => {
  assert.equal(isPaidPurchaseEvent({ period_type: "NORMAL", price: 9.99 }), true);
  assert.equal(isPaidPurchaseEvent({ period_type: "INTRO", price: 9.99 }), true);
  assert.equal(
    isPaidPurchaseEvent({ period_type: "NORMAL", is_trial_conversion: true }),
    true
  );
});

test("annual product ids are recognized", () => {
  assert.equal(isAnnualProduct("com.useprocess.annual3499"), true);
  assert.equal(isAnnualProduct("com.useprocess.monthly999"), false);
});

test("trial entitlement is not a paid subscription", () => {
  const future = new Date(Date.now() + 86_400_000).toISOString();
  const subscriber = {
    subscriber: {
      entitlements: {
        premium: {
          expires_date: future,
          product_identifier: "com.useprocess.monthly999",
        },
      },
      subscriptions: {
        "com.useprocess.monthly999": { period_type: "trial" },
      },
    },
  };
  assert.equal(hasPaidPremium(subscriber, "premium"), false);
});

test("normal paid subscription counts", () => {
  const future = new Date(Date.now() + 86_400_000).toISOString();
  const subscriber = {
    subscriber: {
      entitlements: {
        premium: {
          expires_date: future,
          product_identifier: "com.useprocess.annual3499",
        },
      },
      subscriptions: {
        "com.useprocess.annual3499": { period_type: "normal" },
      },
    },
  };
  assert.equal(hasPaidPremium(subscriber, "premium"), true);
});
