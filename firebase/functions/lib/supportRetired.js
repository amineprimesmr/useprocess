"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.supportSendMessage = void 0;
const https_1 = require("firebase-functions/v2/https");
const referralShared_1 = require("./referralShared");
// Older app versions used this endpoint. No messages or personal data are stored.
exports.supportSendMessage = (0, https_1.onRequest)({ region: "us-central1", maxInstances: 2, secrets: [] }, (req, res) => {
    (0, referralShared_1.setCors)(res);
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    res.status(410).json({ error: "support_chat_retired", email: "contact@processdebloat.com" });
});
//# sourceMappingURL=supportRetired.js.map