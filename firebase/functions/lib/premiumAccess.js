"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PREMIUM_ENTITLEMENT_ID = void 0;
exports.verifyPremiumSubscriber = verifyPremiumSubscriber;
const revenueCat_1 = require("./revenueCat");
exports.PREMIUM_ENTITLEMENT_ID = "premium";
async function verifyPremiumSubscriber(appUserId, secretKey) {
    const subscriber = await (0, revenueCat_1.fetchSubscriber)(appUserId, secretKey);
    if (!(0, revenueCat_1.hasActivePremium)(subscriber, exports.PREMIUM_ENTITLEMENT_ID)) {
        throw new Error("PREMIUM_REQUIRED");
    }
}
//# sourceMappingURL=premiumAccess.js.map