"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeModel = normalizeModel;
exports.validateCoachBody = validateCoachBody;
exports.maxTokensForTask = maxTokensForTask;
exports.httpStatusForError = httpStatusForError;
function normalizeModel(model) {
    switch (model) {
        case "claude-sonnet-4-20250514":
        case "claude-3-7-sonnet-20250219":
        case "claude-3-5-sonnet-20240620":
        case "claude-3-5-sonnet-20241022":
        case "claude-sonnet-4-5-20250929":
            return "claude-sonnet-4-6";
        case "claude-opus-4-20250514":
        case "claude-opus-4-1-20250805":
        case "claude-opus-4-6":
        case "claude-opus-4-7":
        case "claude-opus-4-5-20251101":
            return "claude-opus-4-8";
        case "claude-3-5-haiku-20241022":
        case "claude-3-haiku-20240307":
            return "claude-haiku-4-5-20251001";
        default:
            return "claude-sonnet-4-6";
    }
}
const allowedTasks = new Set([
    "chat",
    "dailyBrief",
    "readinessAnalysis",
    "bodyScanVision",
    "faceScanVision",
    "bodyScanReport",
    "programSummary",
    "tool",
]);
function validateCoachBody(body) {
    if (!body?.system || !body?.userText || !body?.model) {
        return "Missing system, userText or model";
    }
    if (!allowedTasks.has(body.task))
        return "Unsupported task";
    if (body.system.length > 40_000)
        return "System prompt too large";
    if (body.userText.length > 30_000)
        return "User message too large";
    if ((body.imageBase64?.length ?? 0) > 12_000_000)
        return "Image too large";
    if ((body.history?.length ?? 0) > 100)
        return "History too large";
    if (body.history?.some((message) => message.text.length > 30_000)) {
        return "History message too large";
    }
    return null;
}
function maxTokensForTask(task, requested) {
    if (requested && requested > 0)
        return Math.min(requested, 4096);
    switch (task) {
        case "dailyBrief":
        case "readinessAnalysis":
            return 400;
        case "bodyScanVision":
        case "faceScanVision":
            return 450;
        case "programSummary":
            return 800;
        case "bodyScanReport":
            return 1600;
        default:
            return 1200;
    }
}
function httpStatusForError(message) {
    if (message === "UNAUTHORIZED")
        return 401;
    if (message === "INVALID_APP_CHECK")
        return 403;
    if (message === "RATE_LIMITED")
        return 429;
    return 500;
}
//# sourceMappingURL=coachValidation.js.map