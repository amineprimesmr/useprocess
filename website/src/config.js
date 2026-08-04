/** Stub — site Process statique, pas de backend Myfidpass. */

export const API_BASE = "";

export function getAuthToken() {
  return null;
}

export function setAuthToken() {}

export function setRefreshToken() {}

export function clearPendingEstablishments() {}

export function getPendingEstablishment() {
  return null;
}

export function setPendingEstablishment() {}

export async function checkGooglePlaceAvailable() {
  return { ok: true, available: true };
}

export function consumeAuthTransferFromHash() {}

export function wireNativeAuthBridge() {}
