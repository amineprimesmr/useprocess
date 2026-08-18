import { siteStorefront } from "./app-copy.js";

/** URLs App Store — Process (iOS). */
export function getIosAppStoreUrl() {
  const direct =
    typeof import.meta !== "undefined"
      ? String(import.meta.env?.VITE_APP_STORE_IOS_URL || "").trim()
      : "";
  if (direct) return direct;
  const storefront = siteStorefront();
  const id =
    typeof import.meta !== "undefined"
      ? String(import.meta.env?.VITE_IOS_APP_STORE_ID || "").trim()
      : "";
  if (id) return `https://apps.apple.com/${storefront}/app/id${id}`;
  return `https://apps.apple.com/${storefront}/app/process-debloat-ton-visage/id6753808143`;
}

export function getAndroidAppStoreUrl() {
  return "https://play.google.com/store/search?q=Process+AI&c=apps";
}
