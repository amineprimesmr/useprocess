const test = require("node:test");
const assert = require("node:assert/strict");
const {
  httpStatusForError,
  maxTokensForTask,
  normalizeModel,
  validateCoachBody,
} = require("../lib/coachValidation.js");

const validBody = {
  task: "chat",
  model: "claude-sonnet-4-6",
  system: "Tu es un coach.",
  userText: "Bonjour",
};

test("unknown models are forced to the production default", () => {
  assert.equal(normalizeModel("attacker-controlled-model"), "claude-sonnet-4-6");
});

test("valid coach payload is accepted", () => {
  assert.equal(validateCoachBody(validBody), null);
});

test("oversized and unsupported payloads are rejected", () => {
  assert.equal(
    validateCoachBody({ ...validBody, task: "invalid" }),
    "Unsupported task"
  );
  assert.equal(
    validateCoachBody({ ...validBody, userText: "x".repeat(30_001) }),
    "User message too large"
  );
});

test("token requests are capped", () => {
  assert.equal(maxTokensForTask("chat", 99_999), 4096);
  assert.equal(maxTokensForTask("dailyBrief"), 400);
});

test("security errors map to explicit HTTP statuses", () => {
  assert.equal(httpStatusForError("UNAUTHORIZED"), 401);
  assert.equal(httpStatusForError("INVALID_APP_CHECK"), 403);
  assert.equal(httpStatusForError("RATE_LIMITED"), 429);
  assert.equal(httpStatusForError("OTHER"), 500);
});
