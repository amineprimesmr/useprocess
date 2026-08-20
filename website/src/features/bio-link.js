/** Lien bio App Store — compatible TikTok (escape Safari). */
export const APP_BIO_SHORT_URL = "https://useprocess.xyz/app";

/** Anciens chemins — redirigés vers /app côté Vercel. */
export const APP_BIO_SHORT_ALIASES = [
  "https://useprocess.xyz/get",
  "https://useprocess.xyz/i",
  "https://useprocess.xyz/a",
  "https://useprocess.xyz/telecharger",
  "https://get.useprocess.xyz",
];

export function getAppBioShortUrl() {
  return APP_BIO_SHORT_URL;
}
