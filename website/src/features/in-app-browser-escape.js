/** Détecte les navigateurs in-app (TikTok, Instagram, etc.). */
export function detectInAppBrowser() {
  if (typeof navigator === "undefined") return null;

  const ua = navigator.userAgent || "";

  if (
    /BytedanceWebview/i.test(ua) ||
    /musical_ly[_/]/i.test(ua) ||
    /AppName\/musical_ly/i.test(ua) ||
    /TikTok|trill_|com\.ss\.android\.ugc\.trill/i.test(ua)
  ) {
    return "tiktok";
  }
  if (/Barcelona/i.test(ua)) return "threads";
  if (/Instagram/i.test(ua)) return "instagram";
  if (/FBAN|FBAV|FB_IAB/i.test(ua)) return "facebook";
  if (/Twitter/i.test(ua)) return "twitter";
  if (/LinkedInApp|LinkedIn/i.test(ua)) return "linkedin";
  if (/Snapchat/i.test(ua)) return "snapchat";
  if (/Reddit\//i.test(ua)) return "reddit";

  return null;
}

export function isIosDevice() {
  if (typeof navigator === "undefined") return false;
  return /iPhone|iPad|iPod/i.test(navigator.userAgent || "");
}

export function isAndroidDevice() {
  if (typeof navigator === "undefined") return false;
  return /Android/i.test(navigator.userAgent || "");
}

function siteOrigin() {
  if (typeof window !== "undefined" && window.location?.origin) {
    return window.location.origin;
  }
  return "https://useprocess.xyz";
}

/** Page intermédiaire ouverte dans Safari avant l’App Store. */
export function getSafariStoreLandingUrl() {
  return `${siteOrigin()}/app?stay=1`;
}

function iosEscapeHref(targetUrl, app) {
  const encoded = encodeURIComponent(targetUrl);

  if (app === "instagram" || app === "threads") {
    return `instagram://extbrowser/?url=${encoded}`;
  }

  return targetUrl.replace(/^https:\/\//i, "x-safari-https://");
}

function androidEscapeHref(targetUrl) {
  const url = new URL(targetUrl);
  return (
    `intent://${url.host}${url.pathname}${url.search}` +
    `#Intent;scheme=https;S.browser_fallback_url=${encodeURIComponent(targetUrl)};end`
  );
}

/**
 * TikTok bloque apps.apple.com dans son WebView.
 * On envoie d’abord vers notre page /get dans Safari, puis l’App Store depuis Safari.
 */
export function getStoreButtonHref(appStoreUrl) {
  const inApp = detectInAppBrowser();
  if (!inApp) return appStoreUrl;

  const landingUrl = getSafariStoreLandingUrl();

  if (isIosDevice()) {
    return iosEscapeHref(landingUrl, inApp);
  }

  if (isAndroidDevice()) {
    return androidEscapeHref(landingUrl);
  }

  return landingUrl;
}

/** true si le lien App Store risque d’être bloqué dans le WebView courant. */
export function shouldUseSafariStoreFlow() {
  return Boolean(detectInAppBrowser());
}

/**
 * Ouvre une URL HTTPS dans Safari/Chrome depuis un WebView in-app.
 * Doit être appelé dans un geste utilisateur (click/tap).
 */
export function openInExternalBrowser(targetUrl) {
  const app = detectInAppBrowser();

  if (isIosDevice()) {
    window.location.href = iosEscapeHref(targetUrl, app);
    return;
  }

  if (isAndroidDevice()) {
    window.location.href = androidEscapeHref(targetUrl);
    return;
  }

  window.open(targetUrl, "_blank", "noopener,noreferrer");
}
