const test = require("node:test");
const assert = require("node:assert/strict");
const {
  utcDayKey,
  utcHourKey,
  lastNDayKeys,
  sanitizeVisitorId,
  isLikelyBotUserAgent,
  emptyDailySeries,
} = require("../lib/affiliateAnalytics.js");

test("utc day keys are zero-padded UTC dates", () => {
  assert.equal(utcDayKey(new Date("2026-08-25T23:30:00.000Z")), "2026-08-25");
  assert.equal(utcHourKey(new Date("2026-08-25T09:12:00.000Z")), "2026-08-25T09");
});

test("lastNDayKeys returns inclusive chronological windows", () => {
  const keys = lastNDayKeys(3, new Date("2026-08-25T12:00:00.000Z"));
  assert.deepEqual(keys, ["2026-08-23", "2026-08-24", "2026-08-25"]);
});

test("sanitizeVisitorId keeps a stable token", () => {
  assert.equal(sanitizeVisitorId("  ab12-CD34_ef  "), "ab12-CD34_ef");
  assert.equal(sanitizeVisitorId("bad id!!!"), "badid");
  assert.equal(sanitizeVisitorId(""), "");
});

test("bot user-agents are skipped, TikTok in-app is kept", () => {
  assert.equal(isLikelyBotUserAgent("facebookexternalhit/1.1"), true);
  assert.equal(isLikelyBotUserAgent("Twitterbot/1.0"), true);
  assert.equal(
    isLikelyBotUserAgent(
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 musical_ly_40.0.0"
    ),
    false
  );
  assert.equal(
    isLikelyBotUserAgent(
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    ),
    false
  );
});

test("empty daily series has aligned zeros", () => {
  const series = emptyDailySeries(30);
  assert.equal(series.days.length, 30);
  assert.equal(series.linkViews.length, 30);
  assert.equal(series.paywalls.every((n) => n === 0), true);
});
