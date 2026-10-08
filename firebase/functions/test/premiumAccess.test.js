const test = require("node:test");
const assert = require("node:assert/strict");
const Module = require("node:module");
const revenueCat = require("../lib/revenueCat");
let subscriber;
let networkError;
const original = Module._load;
Module._load = function(name, parent, isMain) {
  if (name === "./revenueCat" && parent.filename.endsWith("premiumAccess.js")) {
    return { ...revenueCat, fetchSubscriber: async () => {
      if (networkError) throw networkError;
      return subscriber;
    }};
  }
  return original.call(this, name, parent, isMain);
};
const {verifyPremiumSubscriber} = require("../lib/premiumAccess");
Module._load = original;
const payload = (product, expires) => ({subscriber: {entitlements: {premium: {
  product_identifier: product, expires_date: expires
}}}});
test("Apple monthly, annual and lifetime entitlements unlock server features", async () => {
  for (const product of ["com.useprocess.monthly999", "com.useprocess.annual3499", "com.useprocess.lifetime"]) {
    subscriber = payload(product, product.endsWith("lifetime") ? null : new Date(Date.now()+60000).toISOString());
    await verifyPremiumSubscriber("buyer", "server-secret");
  }
});
test("missing, expired and malformed expiry never unlock paid features", async () => {
  for (const value of [{}, payload("com.useprocess.annual3499", new Date(Date.now()-1000).toISOString()), payload("com.useprocess.annual3499", "invalid")]) {
    subscriber = value;
    await assert.rejects(verifyPremiumSubscriber("buyer", "server-secret"), /PREMIUM_REQUIRED/);
  }
});
test("external sandbox proof cannot substitute an Apple entitlement", async () => {
  subscriber = {};
  await assert.rejects(verifyPremiumSubscriber("buyer", "server-secret", "forged-external-proof"), /PREMIUM_REQUIRED/);
});
test("RevenueCat outage fails closed", async () => {
  networkError = new Error("NETWORK_UNAVAILABLE");
  try { await assert.rejects(verifyPremiumSubscriber("buyer", "server-secret"), /NETWORK_UNAVAILABLE/); }
  finally { networkError = undefined; }
});
