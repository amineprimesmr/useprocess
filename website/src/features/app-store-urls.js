/** URLs App Store — Process AI (iOS). */
export function getIosAppStoreUrl() {
  const direct =
    typeof import.meta !== "undefined"
      ? String(import.meta.env?.VITE_APP_STORE_IOS_URL || "").trim()
      : "";
  if (direct) return direct;
  const id =
    typeof import.meta !== "undefined"
      ? String(import.meta.env?.VITE_IOS_APP_STORE_ID || "").trim()
      : "";
  if (id) return `https://apps.apple.com/fr/app/id${id}`;
  return "https://apps.apple.com/fr/search?term=Process%20AI";
}

export function getAndroidAppStoreUrl() {
  return "https://play.google.com/store/search?q=Process+AI&c=apps";
}
