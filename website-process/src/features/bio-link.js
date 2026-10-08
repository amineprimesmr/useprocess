/** Lien bio App Store — compatible TikTok (escape Safari). */
export const APP_BIO_SHORT_URL = "https://processdebloat.com/app";

/** Anciens chemins — redirigés vers /app côté Vercel. */
export const APP_BIO_SHORT_ALIASES = [
  "https://processdebloat.com/get",
  "https://processdebloat.com/i",
  "https://processdebloat.com/a",
  "https://processdebloat.com/telecharger",
  "https://get.useprocess.xyz",
];

export function getAppBioShortUrl() {
  return APP_BIO_SHORT_URL;
}
