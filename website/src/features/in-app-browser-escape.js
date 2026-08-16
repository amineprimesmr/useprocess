/** Détecte les navigateurs in-app (TikTok, Instagram, etc.). */
export function detectInAppBrowser() {
  const ua = navigator.userAgent || "";

  if (/TikTok|musical_ly|trill_|BytedanceWebview/i.test(ua)) return "tiktok";
  if (/Barcelona/i.test(ua)) return "threads";
  if (/Instagram/i.test(ua)) return "instagram";
  if (/FBAN|FBAV/i.test(ua)) return "facebook";
  if (/Twitter/i.test(ua)) return "twitter";
  if (/LinkedIn/i.test(ua)) return "linkedin";
  if (/Snapchat/i.test(ua)) return "snapchat";
  if (/Reddit/i.test(ua)) return "reddit";

  return null;
}

function iosExternalBrowserUrl(targetUrl, app) {
  const encoded = encodeURIComponent(targetUrl);

  if (app === "instagram" || app === "threads") {
    return `instagram://extbrowser/?url=${encoded}`;
  }

  return targetUrl.replace(/^https:\/\//i, "x-safari-https://");
}

function androidExternalBrowserUrl(targetUrl) {
  const url = new URL(targetUrl);
  return (
    `intent://${url.host}${url.pathname}${url.search}` +
    `#Intent;scheme=https;S.browser_fallback_url=${encodeURIComponent(targetUrl)};end`
  );
}

/**
 * Ouvre une URL dans Safari/Chrome depuis un WebView in-app.
 * Doit être appelé dans un geste utilisateur (click/tap).
 */
export function openInExternalBrowser(targetUrl) {
  const ua = navigator.userAgent || "";
  const app = detectInAppBrowser();

  if (/iPhone|iPad|iPod/i.test(ua)) {
    window.location.assign(iosExternalBrowserUrl(targetUrl, app));
    return;
  }

  if (/Android/i.test(ua)) {
    window.location.assign(androidExternalBrowserUrl(targetUrl));
    return;
  }

  window.open(targetUrl, "_blank", "noopener,noreferrer");
}

/** true si le lien App Store risque d’être bloqué dans le WebView courant. */
export function shouldEscapeBeforeStoreRedirect() {
  return Boolean(detectInAppBrowser());
}
