const test = require("node:test");
const assert = require("node:assert/strict");
const {
  REFERRAL_CODE_LENGTH,
  AFFILIATE_LIFETIME_PASS_CODE,
  normalizeReferralCode,
  isValidReferralCode,
  isReservedLifetimePassCode,
} = require("../lib/referralShared.js");

test("referral codes are exactly five alphanumeric characters", () => {
  assert.equal(REFERRAL_CODE_LENGTH, 5);
  assert.equal(normalizeReferralCode("  k7x2m  "), "K7X2M");
  assert.equal(normalizeReferralCode("AB-CD-EF"), "ABCDE");
  assert.equal(normalizeReferralCode("TOOLONGCODE"), "TOOLO");
  assert.equal(isValidReferralCode("K7X2M"), true);
  assert.equal(isValidReferralCode("ABC"), false);
  assert.equal(isValidReferralCode(""), false);
});

test("affiliate lifetime pass code is reserved", () => {
  assert.equal(AFFILIATE_LIFETIME_PASS_CODE, "CREW7");
  assert.equal(isReservedLifetimePassCode("crew7"), true);
  assert.equal(isReservedLifetimePassCode(" CREW7 "), true);
  assert.equal(isReservedLifetimePassCode("K7X2M"), false);
});
