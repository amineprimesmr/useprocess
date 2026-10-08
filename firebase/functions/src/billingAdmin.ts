import { getFirestore } from "firebase-admin/firestore";
// index.ts initializes Firebase before loading billing exports.
export const db = getFirestore();
