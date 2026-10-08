"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.db = void 0;
const firestore_1 = require("firebase-admin/firestore");
// index.ts initializes Firebase before loading billing exports.
exports.db = (0, firestore_1.getFirestore)();
//# sourceMappingURL=billingAdmin.js.map